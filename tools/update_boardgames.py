import json
import os
import sys
import time
import re
import argparse
from datetime import datetime

try:
    import requests
    from bs4 import BeautifulSoup
    from selenium import webdriver
    from selenium.webdriver.chrome.options import Options
except ImportError:
    print("필요한 패키지가 설치되지 않았습니다.")
    print("pip3 install selenium beautifulsoup4 requests")
    sys.exit(1)

def normalize_name(name):
    if not name:
        return ""
    name = name.lower()
    name = re.sub(r'^(a|an|the)\s+', '', name)
    name = re.sub(r'[^a-z0-9]', '', name)
    return name

def scrape_bgg(start_page, end_page):
    print(f"\n[1/3] BGG {start_page}페이지 ~ {end_page}페이지 크롤링 시작...")
    options = Options()
    # options.add_argument("--headless=new") 
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    options.add_experimental_option('useAutomationExtension', False)

    try:
        driver = webdriver.Chrome(options=options)
    except Exception as e:
        print(f"Chrome 웹드라이버 에러: {e}")
        sys.exit(1)
        
    driver.execute_cdp_cmd('Network.setUserAgentOverride', {"userAgent": 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'})
    driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
    
    games = {}
    crawl_date = datetime.now().isoformat()
    
    try:
        for page in range(start_page, end_page + 1):
            url = f"https://boardgamegeek.com/browse/boardgame/page/{page}"
            print(f"BGG {page}페이지 스크랩 중: {url} ...")
            
            try:
                driver.get(url)
            except Exception as e:
                print(f"페이지 로드 실패: {e}")
                break
                
            if page == start_page:
                time.sleep(10)
            else:
                time.sleep(4)
            
            soup = BeautifulSoup(driver.page_source, "html.parser")
            rows = soup.find_all("tr", id=lambda x: x and x.startswith("row_"))
            
            if not rows:
                print(f"경고: {page}페이지에서 게임을 찾지 못했습니다. Cloudflare 차단일 수 있습니다.")
                continue
            
            for row in rows:
                name_cell = row.find("td", class_="collection_objectname")
                if not name_cell:
                    continue
                
                a_tag = name_cell.find("a", class_="primary")
                if not a_tag:
                    continue
                
                name = a_tag.text.strip()
                href = a_tag["href"]
                bgg_id = href.split("/")[2]
                
                thumb_cell = row.find("td", class_="collection_thumbnail")
                thumbnail_url = ""
                if thumb_cell:
                    img_tag = thumb_cell.find("img")
                    if img_tag and img_tag.has_attr("src"):
                        thumbnail_url = img_tag["src"]
                
                rating_cells = row.find_all("td", class_="collection_bggrating")
                geek_rating = rating_cells[0].text.strip() if len(rating_cells) > 0 else ""
                avg_rating = rating_cells[1].text.strip() if len(rating_cells) > 1 else ""
                num_voters = rating_cells[2].text.strip() if len(rating_cells) > 2 else ""
                
                shop_cell = row.find("td", class_="collection_shop")
                shop_info_list = []
                if shop_cell:
                    aad_div = shop_cell.find("div", class_="aad")
                    if aad_div:
                        container = aad_div.find("div")
                        if container:
                            for child in container.find_all("div", recursive=False):
                                text = child.get_text(separator=' ', strip=True).replace('\xa0', ' ')
                                if text:
                                    shop_info_list.append(text)
                
                game_id = f"bgg_{bgg_id}"
                
                games[game_id] = {
                    "id": game_id,
                    "name": name,
                    "aliases": [],
                    "thumbnailUrl": thumbnail_url,
                    "geekRating": geek_rating,
                    "avgRating": avg_rating,
                    "numVoters": num_voters,
                    "shopInfo": shop_info_list,
                    "lastUpdated": crawl_date
                }
                
            print(f"-> BGG {page}페이지 완료.")
            
    finally:
        driver.quit()
        
    return games

def scrape_boardlife():
    print(f"\n[2/3] 보드라이프 영문명-한글명 매핑 데이터 수집 시작 (1~40페이지)...")
    eng_to_kor = {}
    headers = {"User-Agent": "Mozilla/5.0"}
    
    for page in range(1, 41):
        url = f"https://boardlife.co.kr/rank/all/{page}"
        sys.stdout.write(f"\r보드라이프 {page}/40 페이지 스크랩 중...")
        sys.stdout.flush()
        try:
            res = requests.get(url, headers=headers, timeout=10)
        except Exception:
            try:
                res = requests.get(url, headers=headers, timeout=10)
            except Exception:
                continue
                
        soup = BeautifulSoup(res.text, "html.parser")
        rows = soup.find_all(class_=lambda x: x and 'rank-row' in x)
        if not rows:
            break
            
        for row in rows:
            kr_title_tag = row.find("a", class_="title")
            eng_title_tag = row.find("div", class_="eng")
            
            if kr_title_tag and eng_title_tag:
                kr_name = kr_title_tag.text.strip()
                eng_name = eng_title_tag.text.strip()
                
                norm_eng = normalize_name(eng_name)
                if norm_eng and kr_name:
                    eng_to_kor[norm_eng] = kr_name
                    
        time.sleep(1)
        
    print(f"\n-> 총 {len(eng_to_kor)}개의 한글명 매핑 수집 완료.")
    return eng_to_kor

def main():
    parser = argparse.ArgumentParser(description="BGG 순위와 보드라이프 한글명을 가져와 json에 업데이트합니다.")
    parser.add_argument("from_rank", type=int, help="시작 순위 (예: 1)")
    parser.add_argument("to_rank", type=int, help="종료 순위 (예: 100)")
    args = parser.parse_args()
    
    if args.from_rank < 1 or args.to_rank < args.from_rank:
        print("순위 범위가 잘못되었습니다.")
        sys.exit(1)
        
    # 1페이지당 100개씩 표시되므로 페이지 번호 계산
    start_page = (args.from_rank - 1) // 100 + 1
    end_page = (args.to_rank - 1) // 100 + 1
    
    bgg_games = scrape_bgg(start_page, end_page)
    
    if not bgg_games:
        print("가져온 BGG 게임이 없습니다. 종료합니다.")
        sys.exit(1)
        
    eng_to_kor = scrape_boardlife()
    
    print("\n[3/3] JSON 파일 업데이트 중...")
    db_path = "assets/card_db/boardgames.json"
    db = {"battleDefaults": {
        "hp": 100,
        "atkMin": 10,
        "atkMax": 20,
        "def": 0
    }, "boardgames": []}
    
    if os.path.exists(db_path):
        with open(db_path, "r", encoding="utf-8") as f:
            try:
                loaded_db = json.load(f)
                if "battleDefaults" in loaded_db:
                    db["battleDefaults"] = loaded_db["battleDefaults"]
                if "boardgames" in loaded_db:
                    db["boardgames"] = loaded_db["boardgames"]
            except Exception as e:
                print(f"기존 JSON 로드 실패: {e}")
                
    old_boardgames = db.get("boardgames", [])
    game_dict = {g["id"]: g for g in old_boardgames}
    
    # 병합
    added_count = 0
    updated_count = 0
    
    for gid, gdata in bgg_games.items():
        if gid in game_dict:
            game_dict[gid].update(gdata)
            updated_count += 1
        else:
            game_dict[gid] = gdata
            added_count += 1
            
    # 정렬 유지
    final_list = []
    seen = set()
    for old_g in old_boardgames:
        gid = old_g["id"]
        final_list.append(game_dict[gid])
        seen.add(gid)
        
    for gid in bgg_games.keys():
        if gid not in seen:
            final_list.append(game_dict[gid])
            seen.add(gid)
            
    # 한글명 일괄 적용 (기존 데이터 포함 전체 탐색)
    kor_added = 0
    for game in final_list:
        norm_eng = normalize_name(game.get("name", ""))
        if norm_eng in eng_to_kor:
            kr_name = eng_to_kor[norm_eng]
            if game.get("name_ko") != kr_name:
                game["name_ko"] = kr_name
                kor_added += 1
                
    db["boardgames"] = final_list
    
    with open(db_path, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2, ensure_ascii=False)
        
    print(f"\n최종 완료!")
    print(f"- BGG 정보: {added_count}개 신규 추가, {updated_count}개 기존 항목 업데이트")
    print(f"- 한글 명칭: {kor_added}개 항목에 한글명(aliases) 매핑/추가됨")
    print(f"- 총 저장된 게임 수: {len(final_list)}개")

if __name__ == "__main__":
    main()
��된 게임 수: {len(final_list)}개")

if __name__ == "__main__":
    main()
