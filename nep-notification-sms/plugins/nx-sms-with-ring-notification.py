#!/usr/bin/env python3
"""
Script Name: nx-sms-with-ring-notification.py
Description: Handles SMS and Voice Ring notifications for NetEye/Icinga using SMSD spool files.
Author:      Vladimir Mozharov, Rocco Pezzani
Copyright:   2026 Wuerth IT Italy
Version:     2.1.0
Maintainer:  Vladimir.Mozharov@wuerth-it.com
"""

import argparse
import grp
import logging
import os
import pwd
import re
import shutil
import subprocess
import sys
import tempfile
from argparse import Namespace
from datetime import datetime
from logging import Logger
from typing import Tuple

DESCRIPTION = """
Examples:
    # SMS only
    nx-sms-with-ring-notification.py -r +393234567890 -l router-01 -n "Core Router 01" -o "No ping" \\
        -s DOWN -t PROBLEM -4 10.0.0.1

    # SMS + Ring with custom tone
    nx-sms-with-ring-notification.py -r 00393234567890 -l router-01 -n "Core Router 01" -o "No ping" \\
        -s DOWN -t PROBLEM -R +390987654321 -T "TIME: 45 3,2,3,5,2" -v
"""

LOG_DIR = "/neteye/local/smsd/log"
NOTIFICATION_LOG_FILE: str = os.path.join(LOG_DIR, "notification.log")
SMS_LOG_FILE: str = os.path.join(LOG_DIR, "sms-notification.log")
RING_LOG_FILE: str = os.path.join(LOG_DIR, "phone-call.log")

DEFAULT_SPOOL_PATH: str = "/neteye/local/smsd/data/spool/outgoing"
DEFAULT_SPOOL_USER: str = "icinga"
DEFAULT_SPOOL_GROUP: str = "icinga"
DEFAULT_TONE: str = "TIME: 60 1,9,3,3,6,2,2,1,2,3,6"

# E.164 total digit range (country code included): 7–15.
_E164_MIN_DIGITS = 7
_E164_MAX_DIGITS = 15

class CompactArgumentParser(argparse.ArgumentParser):
    """ArgumentParser that prints a compact error block instead of the full help."""

    def format_usage(self) -> str:
        """Return a single-line synopsis without the full argument list."""
        return f"Usage: {self.prog} -r PHONE -t TYPE -s STATE -o OUTPUT -l HOST [options]\n"

    def error(self, message: str) -> None:
        """Print the error and a short usage hint, then exit with code 2."""
        self.print_usage(sys.stderr)
        self.exit(2, f"\nERROR: {message}\n\nRun with -h/--help for full usage.\n")

def validate_phone_number(raw: str, param_name: str) -> str:
    """Validate and normalize a phone number for use with SMSD.

    Accepts Italian mobile, Italian landline and international numbers.
    Always returns the canonical E.164 form (e.g. ``+393331234567``).

    Raises :class:`argparse.ArgumentTypeError` with a descriptive, human-
    readable message for every detected error condition.

    Validation rules
    ----------------
    * For empty string o string composed by only space an error raised;
    * Formatting characters (spaces, hyphens, dots, parentheses) are stripped
      before any other check; they are never reported as errors on their own.
    * Any remaining non-digit character other than a leading ``+`` is rejected
      and the offending characters are listed in the error message.
    * A number without an international prefix is always considered like
    italian one. +39 automatically added and after number is validated
    * ``0039…`` is normalised to ``+39…`` before further checks.
    * Numbers with ``+39`` (or ``0039``) are validated against Italian mobile
      (``3xx``, exactly 10 digits) and Italian landline (``0x…``, 6–11 digits)
      rules; a precise error is raised for each mismatch.
    * Numbers with any other international prefix are accepted when the total
      digit count (country code + subscriber) is within the E.164 range
      (7–15 digits); otherwise a range error is raised.
    """

    # 1. Reject empty input
    if not raw or not raw.strip():
        raise argparse.ArgumentTypeError(f"{param_name}: phone number cannot be empty.")

    # 2. Strip allowed formatting characters
    cleaned = re.sub(r"[\s\-(). ]+", "", raw)

    # 3. Reject illegal characters (anything that is not a digit or a
    #    single leading '+')
    check = cleaned[1:] if cleaned.startswith("+") else cleaned
    bad_chars = sorted(set(re.findall(r"[^\d]", check)))
    if bad_chars:
        raise argparse.ArgumentTypeError(
            f"{param_name}: invalid characters {bad_chars} found in '{raw}'. "
            f"The number must contain digits only and, optionally, the international "
            f"prefix '+' or '00' (e.g. +39 02 1234567, +49 30 1234567)."
        )

    # 4. Normalise 00xx prefix → +xx
    if cleaned.startswith("00"):
        cleaned = "+" + cleaned[2:]

    # 5. Handle numbers without any international prefix
    #    Accept if they look like an Italian mobile or landline;
    #    silently prepend +39.  Reject everything else.
    if not cleaned.startswith("+"):
        digits = cleaned  # only digits at this point (step 3 guarantees it)

        # Italian mobile: starts with 3, exactly 10 digits
        if digits.startswith("3"):
            if len(digits) < 10:
                raise argparse.ArgumentTypeError(
                    f"{param_name}: Italian mobile number too short in '{raw}': "
                    f"{len(digits)} digits, exactly 10 required "
                    f"(e.g. 333 1234567 or +39 333 1234567)."
                )
            if len(digits) > 10:
                raise argparse.ArgumentTypeError(
                    f"{param_name}: Italian mobile number too long in '{raw}': "
                    f"{len(digits)} digits, exactly 10 required "
                    f"(e.g. 333 1234567 or +39 333 1234567)."
                )
            return "+39" + digits

        # Italian landline: starts with 0, 6–11 digits
        if digits.startswith("0"):
            if len(digits) < 6:
                raise argparse.ArgumentTypeError(
                    f"{param_name}: Italian landline number too short in '{raw}': "
                    f"{len(digits)} digits, minimum is 6 "
                    f"(e.g. 02 12345678 or +39 02 12345678)."
                )
            if len(digits) > 11:
                raise argparse.ArgumentTypeError(
                    f"{param_name}: Italian landline number too long in '{raw}': "
                    f"{len(digits)} digits, maximum is 11 "
                    f"(e.g. 02 12345678 or +39 02 12345678)."
                )
            return "+39" + digits

        # Anything else without a prefix is too ambiguous
        raise argparse.ArgumentTypeError(
            f"{param_name}: missing international prefix in '{raw}'. "
            f"Numbers not starting with '3' (mobile) or '0' (landline) require "
            f"an explicit country code (e.g. +39, +49, 0039)."
        )

    # 6. Split off the leading '+' and it must be something
    all_digits = cleaned[1:]

    if not all_digits:
        raise argparse.ArgumentTypeError(
            f"{param_name}: number is empty after the '+' prefix in '{raw}'."
        )

    # 7. Italian number (+39 / 0039)
    if all_digits.startswith("39"):
        national = all_digits[2:]  # strip country code '39'

        if not national:
            raise argparse.ArgumentTypeError(
                f"{param_name}: incomplete Italian number in '{raw}': "
                f"missing national number after +39."
            )

        # --- Italian mobile (3xx, exactly 10 digits) ---
        if national.startswith("3"):
            if len(national) < 10:
                raise argparse.ArgumentTypeError(
                    f"{param_name}: Italian mobile number too short in '{raw}': "
                    f"{len(national)} digits after +39, exactly 10 required "
                    f"(e.g. +39 333 1234567)."
                )
            if len(national) > 10:
                raise argparse.ArgumentTypeError(
                    f"{param_name}: Italian mobile number too long in '{raw}': "
                    f"{len(national)} digits after +39, exactly 10 required "
                    f"(e.g. +39 333 1234567)."
                )
            return "+39" + national

        # --- Italian landline (0x…, 6–11 digits) ---
        if national.startswith("0"):
            if len(national) < 6:
                raise argparse.ArgumentTypeError(
                    f"{param_name}: Italian landline number too short in '{raw}': "
                    f"{len(national)} digits after +39, minimum is 6 "
                    f"(e.g. +39 02 12345678)."
                )
            if len(national) > 11:
                raise argparse.ArgumentTypeError(
                    f"{param_name}: Italian landline number too long in '{raw}': "
                    f"{len(national)} digits after +39, maximum is 11 "
                    f"(e.g. +39 02 12345678)."
                )
            return "+39" + national

        # --- Neither mobile nor landline ---
        raise argparse.ArgumentTypeError(
            f"{param_name}: '{raw}' is not a valid Italian number. "
            f"After the +39 prefix the number must start with '3' (mobile) "
            f"or '0' (landline). Digit found: '{national[0]}'."
        )

    # 8. Foreign number: E.164 length check (7–15 total digits)
    total_digits = len(all_digits)
    if total_digits < _E164_MIN_DIGITS:
        raise argparse.ArgumentTypeError(
            f"{param_name}: foreign number too short in '{raw}': "
            f"{total_digits} total digits (including country code), minimum {_E164_MIN_DIGITS} "
            f"per E.164 standard."
        )
    if total_digits > _E164_MAX_DIGITS:
        raise argparse.ArgumentTypeError(
            f"{param_name}: foreign number too long in '{raw}': "
            f"{total_digits} total digits (including country code), maximum {_E164_MAX_DIGITS} "
            f"per E.164 standard."
        )

    return "+" + all_digits


def parse_arguments() -> Namespace:
    """Parse CLI arguments for SMS and optional ring notification delivery."""
    parser = CompactArgumentParser(
        description="Send SMS and optional ring notifications by writing SMSD command files.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=DESCRIPTION,
    )

    # Separate argument groups for better help organization and clarity.
    sms_group = parser.add_argument_group("SMS Options")
    ring_group = parser.add_argument_group("Ring Options")

    # SMS-Specific options. Remind that these are mantadory
    sms_group.add_argument(
        "-r",
        "--user-mobile",
        dest="user_mobile",
        required=True,
        type=lambda v: validate_phone_number(v, "--user-mobile"),
        help=(
            "Recipient phone number (mobile or landline). "
            "Prefix required: +39 or 0039 for Italy, +XX or 00XX for foreign numbers. "
            "Examples: +39 333 1234567, +39 02 12345678, +49 30 12345678"
        ),
    )

    # Ring-specific options. Optional. Ring is enabled if --ring_number is provided.
    ring_group.add_argument(
        "-R",
        "--ring-number",
        dest="ring_number",
        type=lambda v: validate_phone_number(v, "--ring-number"),
        help=(
            "Recipient phone number for voice ring (enables ring). "
            "Same format rules as --user-mobile."
        ),
    )
    ring_group.add_argument("-T", "--phone-tone", dest="phone_tone", help="Custom tone")

    # Generic (common) options for both SMS and ring notifications.
    parser.add_argument("-t", "--notification-type", dest="notification_type",
                        required=True, help="NOTIFICATIONTYPE")
    parser.add_argument(
        "-d", "--datetime", help="LONGDATETIME (defaults to current time if omitted)")

    parser.add_argument("-s", "--state", required=True,
                        help="HOST or SERVICE STATE")
    parser.add_argument("-o", "--output", required=True,
                        help="HOST or SERVICE OUTPUT")

    parser.add_argument("-4", "--ipv4", dest="ipv4", help="IPv4 address")
    parser.add_argument("-6", "--ipv6", dest="ipv6", help="IPv6 address")

    parser.add_argument("-l", "--host-name", required=True, dest="host_name", help="HOSTNAME")
    parser.add_argument("-n", "--host-display-name", dest="host_display_name", help="HOSTDISPLAYNAME")
    parser.add_argument("-e", "--service-name", dest="service_name", help="SERVICENAME")
    parser.add_argument("-u", "--service-display-name", dest="service_display_name",
                        help="SERVICEDISPLAYNAME")

    # Advanced configuration options for SMSD spool integration and logging. These have defaults but can be overridden as needed.
    parser.add_argument("--spool-path", default=DEFAULT_SPOOL_PATH, dest="spool_path",
                        help="Outgoing SMSD spool directory")
    parser.add_argument("--spool-user", default=DEFAULT_SPOOL_USER, dest="spool_user",
                        help="Outgoing SMSD spool owner user")
    parser.add_argument("--spool-group", default=DEFAULT_SPOOL_GROUP, dest="spool_group",
                        help="Outgoing SMSD spool owner group")
    parser.add_argument("--log-dir", default=LOG_DIR, dest="log_dir",
                        help="Directory for notification, SMS and ring audit logs")
    parser.add_argument("--smsd-target-server", type=str, dest="smsd_target_server",
                        help="Remote host running SMSD. If set, files are copied there with rsync.")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="Enable debug output")

    # Deprecated options for backward compatibility. These are accepted but ignored, and will be removed in future versions.
    parser.add_argument("-b", "--author", dest="author", help="AUTHOR (deprecated)")
    parser.add_argument("-c", "--comment", dest="comment", help="COMMENT (deprecated)")
    parser.add_argument("-i", "--icingaweb-url", dest="icingaweb_url",
                        help="ICINGAWEB2URL (deprecated)")
    parser.add_argument("-f", "--mail-from", dest="mail_from", help="MAILFROM (deprecated)")

    return parser.parse_args()


def setup_logging(verbose: bool, notification_log_file: str) -> Logger:
    """Configure and return a logger that writes to file and stdout."""
    os.makedirs(os.path.dirname(notification_log_file),
                mode=0o755, exist_ok=True)

    logger = logging.getLogger("nx-sms-with-ring-notification")
    logger.handlers = []
    logger.propagate = False
    logger.setLevel(logging.DEBUG if verbose else logging.INFO)

    formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")

    file_handler = logging.FileHandler(notification_log_file)
    file_handler.setLevel(logging.DEBUG if verbose else logging.INFO)
    file_handler.setFormatter(formatter)

    stream_handler = logging.StreamHandler(sys.stdout)
    stream_handler.setLevel(logging.DEBUG if verbose else logging.INFO)
    stream_handler.setFormatter(formatter)

    logger.addHandler(file_handler)
    logger.addHandler(stream_handler)
    return logger


def get_log_paths(log_dir: str) -> Tuple[str, str, str]:
    """Return notification, SMS, and ring log file paths for the selected directory."""
    return (
        os.path.join(log_dir, "nx-notification.log"),
        os.path.join(log_dir, "nx-notification-sms.log"),
        os.path.join(log_dir, "nx-notification-phone-ring.log"),
    )


def initialize_log_files(logger: Logger, sms_log_file: str, ring_log_file: str) -> None:
    """Create dedicated SMS and ring audit log files if they do not exist."""
    for log_file in [sms_log_file, ring_log_file]:
        if not os.path.exists(log_file):
            with open(log_file, "a"):
                pass
            os.chmod(log_file, 0o664)
            logger.info("Created log file: %s", log_file)


def _ensure_trailing_slash(path: str) -> str:
    """Return a path guaranteed to end with a trailing slash."""
    return path if path.endswith("/") else path + "/"


def _append_audit(log_file: str, line: str) -> None:
    """Append a single formatted audit line to the given log file."""
    with open(log_file, "a") as f:
        f.write(line.rstrip() + "\n")


def write_smsd_file(
        payload: str,
        file_prefix: str,
        spool_path: str,
        spool_user: str,
        spool_group: str,
        spool_server: str,
        logger: Logger,) -> str:
    """Write an SMSD command file and deliver it locally or via rsync.

    The file is first created atomically in a temporary directory with the
    configured ownership and permissions, then moved to the destination spool
    directory (or copied to a remote spool host).
    """
    # Resolve target UID/GID early so permission errors are explicit.
    uid = pwd.getpwnam(spool_user).pw_uid
    gid = grp.getgrnam(spool_group).gr_gid

    # Use a dedicated temp directory to keep generated files grouped together.
    tmp_dir = os.path.join(tempfile.gettempdir(), "nx-smsd")
    os.makedirs(tmp_dir, mode=0o750, exist_ok=True)

    fd, tmp_path = tempfile.mkstemp(prefix=file_prefix, dir=tmp_dir)
    try:
        try:
            os.fchmod(fd, 0o640)
        except AttributeError:
            os.chmod(tmp_path, 0o640)

        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
            f.write(payload)
            if not payload.endswith("\n"):
                f.write("\n")
            f.flush()
            os.fsync(f.fileno())

        os.chown(tmp_path, uid, gid)

        # Remote mode: send the temporary file through rsync.
        if (spool_server or "").strip():
            dest = "{}:{}".format(
                spool_server, _ensure_trailing_slash(spool_path))
            cmd = ["rsync", "-az", "--", tmp_path, dest]
            proc = subprocess.run(
                cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True
            )
            if proc.returncode != 0:
                raise RuntimeError(f"rsync failed (rc={proc.returncode}): stdout={proc.stdout!r} stderr={proc.stderr!r}")
            logger.info("Delivered file to remote spool: %s", dest)
            return tmp_path

        # Local mode: ensure destination spool path exists and is a directory.
        if not os.path.isdir(spool_path):
            raise FileNotFoundError(
                f"spool_path does not exist or is not a directory: {spool_path}")

        # Move into spool atomically from the same filesystem when possible.
        final_path = os.path.join(spool_path, os.path.basename(tmp_path))
        final_path = shutil.move(tmp_path, final_path)
        os.chown(final_path, uid, gid)
        os.chmod(final_path, 0o640)
        logger.info(f"Delivered file to local spool: {final_path}")
        return final_path

    finally:
        # In remote mode, remove temporary file after a successful/failed transfer.
        if os.path.exists(tmp_path) and (spool_server or "").strip():
            try:
                os.remove(tmp_path)
            except Exception:
                pass


def build_sms_payload(args: Namespace) -> str:
    """Build the SMS text payload from parsed notification arguments."""
    # Build a human-readable subject line based on host/service context.
    subject_prefix = f"NetEye [{args.notification_type}]"
    msg_host_name = args.host_display_name or args.host_name

    if args.service_display_name:
        subject = f"{subject_prefix} Service {args.service_display_name} on {msg_host_name} is {args.state}!"
    elif args.service_name:
        subject = f"{subject_prefix} Service {args.service_name} on {msg_host_name} is {args.state}!"
    else:
        subject = f"{subject_prefix} Host {msg_host_name} is {args.state}!"

    # Use provided event time when available; otherwise fallback to current time.
    event_time = args.datetime or datetime.now().strftime("%H:%M %d-%b-%Y")

    # Compose message body and include IP fields only when they are provided.
    lines = [
        f"When:  {event_time}",
        f"Value: {args.output}",
    ]
    if args.ipv4:
        lines.append(f"IPv4:  {args.ipv4}")
    if args.ipv6:
        lines.append(f"IPv6:  {args.ipv6}")

    # SMSD format expects the recipient in the header followed by message content.
    body = "\n".join(lines)
    return f"To: {args.user_mobile}\n\n{subject}\n{body}"


def build_ring_payload(args: Namespace) -> str:
    """Build the ring payload from the already-validated ring number and tone.

    args.ring_number is already normalised to E.164 by validate_phone_number;
    strip the leading '+' and keep only digits for the SMSD voicecall header.
    """
    target_number = args.ring_number.lstrip("+")

    # Use custom tone when provided, otherwise fallback to platform default.
    tone = args.phone_tone if args.phone_tone else DEFAULT_TONE

    # Voicecall payload is interpreted by SMSD based on `Voicecall: yes` and TONE.
    return f"To: {target_number}\nVoicecall: yes\n\nTONE: {tone}"


def send_sms(args: Namespace, logger: Logger, sms_log_file: str) -> int:
    """Send SMS notification by writing a `send.*` file into SMSD spool."""
    # Build the final SMS text envelope to be dropped in the outgoing spool.
    payload = build_sms_payload(args)
    try:
        # `send.` prefix keeps compatibility with existing SMSD spool conventions.
        write_smsd_file(
            payload=payload,
            file_prefix="send.",
            spool_path=args.spool_path,
            spool_user=args.spool_user,
            spool_group=args.spool_group,
            spool_server=args.smsd_target_server or "",
            logger=logger,
        )
        # Store a single-line audit entry for troubleshooting and traceability.
        _append_audit(
            sms_log_file,
            "{}  {}".format(datetime.now().strftime(
                "%a %b %d %Y %H:%M:%S %Z"), payload.replace("\n", " | ")),
        )
        return 0
    except Exception as e:
        # Never raise here; caller controls process exit code based on return value.
        logger.error(f"SMS error: {e}")
        return 1


def send_ring(args: Namespace, logger: Logger, ring_log_file: str) -> int:
    """Send ring notification by writing a `phone.*` file into SMSD spool."""
    try:
        # Prepare ring payload in SMSD-compatible voicecall format.
        payload = build_ring_payload(args)

        # `phone.` prefix indicates voice-call command files for SMSD.
        write_smsd_file(
            payload=payload,
            file_prefix="phone.",
            spool_path=args.spool_path,
            spool_user=args.spool_user,
            spool_group=args.spool_group,
            spool_server=args.smsd_target_server or "",
            logger=logger,
        )
        # Persist ring command details as one-line audit for operations visibility.
        _append_audit(
            ring_log_file,
            "{}  {}".format(datetime.now().strftime(
                "%a %b %d %Y %H:%M:%S %Z"), payload.replace("\n", " | ")),
        )
        return 0
    except Exception as e:
        # Mirror SMS path: log and return non-zero so main can fail the run.
        logger.error("Ring error: %s", e)
        return 1


def main() -> None:
    """Execute end-to-end notification flow and return process exit status."""
    args = parse_arguments()
    notification_log_file, sms_log_file, ring_log_file = get_log_paths(
        args.log_dir)
    logger = setup_logging(args.verbose, notification_log_file)
    initialize_log_files(logger, sms_log_file, ring_log_file)

    logger.debug("Started with args: %s", vars(args))

    sms_status = send_sms(args, logger, sms_log_file)
    ring_status = send_ring(
        args, logger, ring_log_file) if args.ring_number else 0

    if sms_status != 0 or ring_status != 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
