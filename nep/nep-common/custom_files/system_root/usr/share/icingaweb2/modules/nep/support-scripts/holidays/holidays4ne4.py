import holidays
import json
import datetime
import argparse
import configparser
import tempfile
import subprocess

# Percorso assoluto al file di configurazione
config_path = '/neteye/shared/icingaweb2/conf/modules/nep/holidays.ini'

config = configparser.ConfigParser()
config.read(config_path)

parser = argparse.ArgumentParser(description="Generate and apply holidays timeperiod in Icinga Director")
args = parser.parse_args()

current_year = datetime.datetime.now().year
next_year = current_year + 1

for section in config.sections():
    nation = config.get(section, "nation", fallback="").strip().upper()
    region = config.get(section, "region", fallback="").strip().upper()
    print(f"Generate holidays for: {section}")

    if not nation:
        print(f"No nation found in {section}")
        continue

    if region:
        print(f"Generate holidays for: {nation} / {region}")
    else:
        print(f"Generate holidays for: {nation}")

    all_ranges = {}

    for year in [current_year, next_year]:

        try:
            
            holiday_args = {
                "years": year
            }

            if region:
                holiday_args["subdiv"] = region

            country_holidays = getattr(holidays, nation)(**holiday_args)

            for data, name in country_holidays.items():
                formatted_date = data.strftime("%B %d %Y").lower()
                all_ranges[formatted_date] = "00:00-24:00"

        except AttributeError:
            print(f"Nation not supported: {nation}")
            break

    # Build icinga object name, depending on the availability of the region
    object_suffix = nation.lower()

    if region:
        object_suffix += f"_{region.lower()}"

    object_name = f"nx-t-holidays-{object_suffix}"

    output_dict = {
        "TimePeriod": {
            object_name: {
                "display_name": object_name,
                "object_name": object_name,
                "object_type": "object",
                "ranges": all_ranges,
                "update_method": "LegacyTimePeriod"
            }
        }
    }

    json_output = json.dumps(output_dict, indent=4)

    try:
        with tempfile.NamedTemporaryFile(mode='w+', suffix='.json', delete=True, encoding='utf-8') as tmp:
            tmp.write(json_output)
            tmp.flush()
            tmp.seek(0)

            print(f"Execute icingacli for {nation}...")

            command = ["icingacli", "director", "basket", "restore"]
            subprocess.run(command, input=tmp.read(), universal_newlines=True)

            print(f"Holidays for {nation} Done!")

    except subprocess.CalledProcessError as e:
        print(f"Error for holidays nation: {nation}: {e}")
        print(f"Stdout: {e.stdout}")
        print(f"Stderr: {e.stderr}")

    except Exception as e:
        print(f"Error for {nation}: {e}")
