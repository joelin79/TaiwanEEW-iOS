#
#  gen_locale.py
#  TaiwanEEW
#
#  Created by Albert on 2026/8/24.
#

import json
import urllib.request
import ssl
import re

# TC to JP mapping for Shinjitai
char_map = {
    "臺": "台",
    "縣": "県",
    "區": "区",
    "鄉": "郷",
    "觀": "観",
    "豐": "豊",
    "濱": "浜",
    "龜": "亀",
    "鹽": "塩",
    "萬": "万",
    "雙": "双",
    "溪": "渓",
    "彌": "弥",
    "蘆": "芦",
    "龍": "竜"
}

def tc_to_ja(text):
    for k, v in char_map.items():
        text = text.replace(k, v)
    return text

def main():
    ssl._create_default_https_context = ssl._create_unverified_context

    xcstrings_file = "/Users/alber/Dev/EEW/TaiwanEEW-iOS/TaiwanEEW/Localizable.xcstrings"
    swift_file = "/Users/alber/Dev/EEW/TaiwanEEW-iOS/TaiwanEEW/Models/Location.swift"
    
    # download directly English dataset
    url = "https://raw.githubusercontent.com/donma/TaiwanAddressCityAreaRoadChineseEnglishJSON/master/CityCountyData.json"
    req = urllib.request.urlopen(url)
    alldata = json.loads(req.read())
    
    # build english translation dictionary
    trans_dict_en = {}
    for city_entry in alldata:
        city_tc = city_entry.get("CityName", "")
        city_en = city_entry.get("CityEngName", "")
        
        if city_tc:
            trans_dict_en[city_tc] = city_en.strip()
            
        for area_entry in city_entry.get("AreaList", []):
            area_tc = area_entry.get("AreaName", "")
            area_en = area_entry.get("AreaEngName", "")
            if city_tc and area_tc:
                trans_dict_en[city_tc + area_tc] = f"{area_en.strip()}, {city_en.strip()}"
            
    # manual fixes for English dict (Taiwan has "臺" and "台" variants)
    for key, value in list(trans_dict_en.items()):
        if "臺" in key:
            trans_dict_en[key.replace("臺", "台")] = value
        if "台" in key:
            trans_dict_en[key.replace("台", "臺")] = value
            
    print(f"Loaded {len(trans_dict_en)} English mapping entries.")
    
    # read swift file to get exactly valid location strings
    with open(swift_file, 'r', encoding='utf-8') as f:
        content = f.read()
        
    districts = re.findall(r'District\([^,]*,[^,]*,[^,]*,[^,]*,\s*"([^"]+)"\s*\)', content)
    cities = re.findall(r'"(?:[A-Za-z]+City|[A-Za-z]+County)"\s*:\s*"([^"]+)"', content)
    
    all_locations = set(districts + cities)
    print(f"Found {len(all_locations)} distinct location strings to translate.")
    
    with open(xcstrings_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    for tc_str in sorted(list(all_locations)):
        en_str = trans_dict_en.get(tc_str, tc_str)
        ja_str = tc_to_ja(tc_str)
            
        if tc_str not in data["strings"]:
            data["strings"][tc_str] = {
                "extractionState": "manual",
                "localizations": {}
            }
            
        locs = data["strings"][tc_str].get("localizations", {})
        
        # Add English
        locs["en"] = {
            "stringUnit": {
                "state": "translated",
                "value": en_str
            }
        }
        
        # Add Japanese
        locs["ja"] = {
            "stringUnit": {
                "state": "translated",
                "value": ja_str
            }
        }
        
        data["strings"][tc_str]["localizations"] = locs

    with open(xcstrings_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        
    print("Done applying English and Japanese translations.")

if __name__ == "__main__":
    main()
