"""Measure equipment atlas regions without editing generated source imagery."""
import json
from pathlib import Path
from register_menu_characters import measure

ROOT = Path(__file__).resolve().parents[2] / 'assets/menu/equipment'
SHEETS = [('headgear', 4, 'shoot'), ('weapons', 2, 'prop'),
          ('extra_weapons', 2, 'prop'), ('wearables', 4, 'prop'),
          ('hair_bags', 4, 'prop'), ('firearms', 2, 'prop'),
          ('ghillie', 2, 'prop'), ('rifles_throwables', 2, 'prop'),
          ('ammunition', 4, 'prop')]

if __name__ == '__main__':
    result = {}
    for key, rows, action in SHEETS:
        filename = 'melee_weapons.png' if key == 'weapons' else key+'.png'
        # Headgear uses the same neutral-background runtime key as shooting poses.
        result[key] = measure(ROOT/filename, columns=4, rows=rows, action=action)
    (ROOT/'frames.json').write_text(json.dumps(result, indent=2)+'\n')
    print('Registered 104 equipment sprites; source art unchanged.')
