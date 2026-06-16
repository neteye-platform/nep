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

for section in config.sections():
    nazione = config[section]['nation'].upper()
    print(f"Generate holidays for: {nazione}")

    current_year = datetime.datetime.now().year
    next_year = current_year + 1

    all_ranges = {}

    for year in [current_year, next_year]:
        ranges = {}

        try:
            for data, nome in getattr(holidays, nazione)(years=year).items():
                data_formattata = data.strftime("%B %d %Y").lower()
                ranges[data_formattata] = "00:00-24:00"

        except AttributeError:
            print(f"Nation not supported: {nazione}")
            continue

        all_ranges.update(ranges)

    output_dict = {
        "TimePeriod": {
            f"nx-t-holidays-{nazione.lower()}": {
                "display_name": f"nx-t-holidays-{nazione.lower()}",
                "object_name": f"nx-t-holidays-{nazione.lower()}",
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

            print(f"Execute icingacli for {nazione}...")

            command = ["icingacli", "director", "basket", "restore"]
            subprocess.run(command, input=tmp.read(), universal_newlines=True)

            print(f"Holidays for {nazione} Done!")

    except subprocess.CalledProcessError as e:
        print(f"Error for holidays nation: {nazione}: {e}")
        print(f"Stdout: {e.stdout}")
        print(f"Stderr: {e.stderr}")

    except Exception as e:
        print(f"Errore for {nazione}: {e}")
