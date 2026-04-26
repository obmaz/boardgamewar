import json
import sys

def main():
    db_path = "assets/card_db/boardgames.json"
    with open(db_path, "r", encoding="utf-8") as f:
        db = json.load(f)
        
    for game in db.get("boardgames", []):
        aliases = game.get("aliases", [])
        if aliases and len(aliases) > 0:
            game["name_ko"] = aliases[0]
        else:
            game["name_ko"] = None
        if "aliases" in game:
            del game["aliases"]
            
    with open(db_path, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2, ensure_ascii=False)

if __name__ == "__main__":
    main()
