#!/usr/bin/python3
import os
import json
import socket
import base64
import tempfile
import subprocess
import multiprocessing as mp

ROOT = os.path.abspath(os.path.dirname(__file__))

PORT = 63542

TEST_SETTINGS = {
    "url":"http://127.0.0.1:{PORT}/api/now/table/u_monitoring_services".format(PORT=PORT),
    "user":"user",
    "pass":"password",
    "timeout":60,
    "verify":False,
    "cert":None,
    "retries":5,
    "retries_delay":0.5
}

TEST_PAYLOAD = {
    "u_ci_service":"serviceroni",
    "u_message":"mygreatmsg",
    "u_type":"outage",
    "u_start":"2022-02-20T00:00:00.0Z",
    "u_end":"2022-02-21T00:00:00.0Z",
}

TRUTH_ENCODED_PAYLOAD = json.dumps(TEST_PAYLOAD).encode()

OK_RESPONSE = """
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: {}
""".format(len(TRUTH_ENCODED_PAYLOAD)).strip().encode()

def mock_endpoint():
    print("Started mock endpoint on port {}".format(PORT))
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        # set REUSEADDR to avoid addr already in use error
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

        s.bind(("127.0.0.1", PORT))
        s.listen()
        conn, addr = s.accept()
        with conn:
            print(f"Connected by {addr}")

            # Recieve header of the HTTP request
            header = b""
            while b"\r\n\r\n" not in header:
                data = conn.recv(1024)
                if not data:
                    break
                header += data

            header, _, packet = header.partition(b"\r\n\r\n")

            # Check tht the url is right
            lines_iter = iter(header.split(b"\r\n"))
            assert b"POST /api/now/table/u_monitoring_services HTTP/1.1" == next(lines_iter)

            # Parse the headers
            headers = dict(
                tuple(
                    x.strip()
                    for x in line.split(b":", 1)
                )
                for line in lines_iter
            )
            print(headers)

            # Test that the payload type and length match what we expect
            content_length = int(headers[b"Content-Length"].decode())
            assert content_length == len(TRUTH_ENCODED_PAYLOAD)
            assert headers[b"Content-Type"] == b'application/json'

            # Test that the authentication works
            truth_authentication = "Basic {}".format(
                base64.b64encode("{user}:{pass}".format(**TEST_SETTINGS).encode()).decode()
            ).encode()
            assert headers[b"Authorization"] == truth_authentication, "{} != {}".format(
                headers[b"Authorization"], truth_authentication
            )

            # Receive the all the payload (if needed)
            while len(packet) < content_length:
                data = conn.recv(1024)
                if not data:
                    break
                packet += data

            print(packet)
            # Assert that the payload is correct
            assert packet == TRUTH_ENCODED_PAYLOAD

            # Tell the client that everything is file
            conn.sendall(OK_RESPONSE)

with tempfile.NamedTemporaryFile() as f:
    f.write(json.dumps(TEST_SETTINGS).encode())
    f.flush()

    # Start a mock endpoint to test our script
    process = mp.Process(target=mock_endpoint)
    process.start()

    # Run the
    print("Running the script with test args")
    sp = subprocess.run([
        "/usr/bin/python3",
        os.path.join(ROOT, "nx-notification-servicenow.py"),
        "--settings={}".format(f.name),
        "--service={u_ci_service}".format(**TEST_PAYLOAD),
        "--message={u_message}".format(**TEST_PAYLOAD),
        "--type={u_type}".format(**TEST_PAYLOAD),
        "--start={u_start}".format(**TEST_PAYLOAD),
        "--end={u_end}".format(**TEST_PAYLOAD),
    ])

    # Check that the script executed correctly
    assert sp.returncode == 0, "Got Exit code {}. Error {}".format(sp.returncode, sp)
    print("Success")

    print("killing the mock endpoint")
    process.kill()