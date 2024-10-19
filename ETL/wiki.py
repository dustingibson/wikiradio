import wikipediaapi, datetime, uuid, sys, pyttsx3, os
import mysql.connector, configparser, random, subprocess
import win32com.client 

class WikipediaArticle:
    def __init__(self, id, title, url, last_retrieved_date, status):
        self.id: str = id
        self.title: str = title
        self.url: str = url
        self.last_retrieved_date: datetime = last_retrieved_date
        self.status = status

    @property
    def last_retrieved_date_str(self) -> str:
        return self.last_retrieved_date.strftime('%Y-%m-%d %H:%M:%S')

class WikipediaSection:
    def __init__(self, id, wikipedia_article_id, wikipedia_parent_section_id, title, content, order_index):
        self.id: str = id
        self.wikipedia_article_id: str = wikipedia_article_id
        self.wikipedia_parent_section_id: str =  wikipedia_parent_section_id
        self.title: str = title
        self.content: str = content
        self.location_file: str = ""
        self.last_retrieved_date: datetime = datetime.datetime.now()
        self.status = "UNINIT"
        self.order_index = order_index

    @property
    def last_retrieved_date_str(self) -> str:
        return self.last_retrieved_date.strftime('%Y-%m-%d %H:%M:%S')

class WikiRadioETL:

    def __init__(self):
        config = configparser.ConfigParser()
        config.read('config.ini')
        self.con = mysql.connector.connect(host=config['sql']['host'], user=config['sql']['username'], password=config['sql']['password'], database='wikiradio',  auth_plugin='mysql_native_password')
        self.machine_name = config['machine']['name']
        self.directory = config['machine']['directory']
        self.expire_in_weeks = 2
        self.tree_order = 0
        self.engine = pyttsx3.init()
        self.voices = [0, 1]
        self.voice = self.voices[random.randint(0, len(self.voices) - 1)]
        self.banned_sections = [""]

    def save_voice(self, id: str, content: str):
        if content != '' and content != None:
            speaker = win32com.client.Dispatch("SAPI.SpVoice") 
            filestream = win32com.client.Dispatch("SAPI.SpFileStream")
            path = self.directory + "/" + id.replace("-", "_") + ".WAV"
            speaker.Rate = 2
            speaker.Voice = speaker.GetVoices().Item(self.voice)
            filestream.Open(path, 3, False)
            speaker.AudioOutputStream = filestream
            speaker.Speak(content)
            filestream.Close()
            self.convert_tts(id, path)

    def convert_tts(self, id: str, path: str):
        try:
            mp3path = path.replace(".WAV", ".MP3")
            subprocess.call(["ffmpeg", "-i", path, "-acodec", "libmp3lame", "-b:a", "32k" , "-ac", "1", "-ar", "11025", mp3path])
            if(os.path.exists(mp3path)):
                os.remove(path)
        except:
            print("Cannot find")

    def sql_data_to_article(self, data) -> WikipediaArticle:
        return WikipediaArticle(data[0], data[1], data[2], data[3], data[4])

    def from_url(self, url) -> WikipediaArticle:
        query: str = "SELECT id, title, url, last_retrieved_date, status FROM WIKIPEDIA_ARTICLES WHERE url=%s"
        cur = self.con.cursor()
        cur.execute(query, [url])
        rows = cur.fetchall()
        if len(rows) >= 1:
            return self. sql_data_to_article(rows[0])
        return None
    
    def mark_completed(self, article: WikipediaArticle):
        ## TODO: Check all files exists and everything
        query: str = "UPDATE WIKIPEDIA_ARTICLES SET STATUS='COMPLETED' WHERE id=%s"
        cur = self.con.cursor()
        cur.execute(query, [article.id])
        self.con.commit()
        cur.close()

    def write_article_to_db(self, wiki_article: WikipediaArticle):
        cur = self.con.cursor()    
        query: str = "INSERT INTO WIKIPEDIA_ARTICLES (id, title, url, last_retrieved_date, status) VALUES (%s, %s, %s, %s, %s)"
        cur = self.con.cursor()
        cur.execute(query, [wiki_article.id, 
                            wiki_article.title, 
                            wiki_article.url, 
                            wiki_article.last_retrieved_date_str, 
                            wiki_article.status])
        self.con.commit()
        cur.close()

    def write_section_to_db(self, wiki_section: WikipediaSection):
        cur = self.con.cursor()
        query: str = """INSERT INTO WIKIPEDIA_SECTIONS (id, wikipedia_article_id, wikipedia_parent_section_id, title, content, location_machine, location_directory, location_file, last_retrieved_date, status, order_index) 
                                                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s,  %s, %s)"""
        cur.execute(query, [wiki_section.id, 
                            wiki_section.wikipedia_article_id, 
                            wiki_section.wikipedia_parent_section_id, 
                            wiki_section.title, 
                            wiki_section.content, 
                            self.machine_name, 
                            self.directory, 
                            None, 
                            wiki_section.last_retrieved_date_str, 
                            wiki_section.status, 
                            wiki_section.order_index ])
        self.con.commit()
        cur.close()

    def preorder_section(self, page: WikipediaArticle, section: wikipediaapi.WikipediaPageSection, parent_id: str):
        if (section == None):
            return
        self.tree_order = self.tree_order + 1
        section_db = WikipediaSection(str(uuid.uuid1()), page.id, parent_id, section.title, section.text, self.tree_order)
        self.write_section_to_db(section_db)
        self.save_voice(section_db.id, section_db.content)
        for new_section in section.sections:
            self.preorder_section(page, new_section, section_db.id)
        
    def is_expired(self, cur_date: datetime) -> bool:
        return cur_date < datetime.datetime.now() - datetime.timedelta(weeks=self.expire_in_weeks)

    def init_new_article(self, wiki_page: wikipediaapi.WikipediaPage) -> WikipediaArticle:
        return WikipediaArticle(str(uuid.uuid1()), wiki_page.title, wiki_page.fullurl, datetime.datetime.now(), 'UNINIT')
    
    def clean_up(self, wiki_article: WikipediaArticle):
        cur = self.con.cursor()
        query: str = """SELECT id, location_directory FROM WIKIPEDIA_SECTIONS WHERE wikipedia_article_id=%s"""
        cur.execute(query, [wiki_article.id])
        rows = cur.fetchall()
        print(len(rows))
        for row in rows:
            cur_fname = row[1] + "/" + row[0].replace("-", "_") + ".MP3"
            if os.path.exists(cur_fname):
                os.remove(cur_fname)
        del_section = """DELETE FROM WIKIPEDIA_SECTIONS WHERE wikipedia_article_id=%s"""
        cur.execute(del_section, [wiki_article.id])
        self.con.commit()
        del_article = """DELETE FROM WIKIPEDIA_ARTICLES WHERE id=%s"""
        cur.execute(del_article, [wiki_article.id])
        self.con.commit()
        cur.close()

    def download_article(self, name):
        wiki = wikipediaapi.Wikipedia('Wikiradio', 'en')
        wiki_page = wiki.page(name)
        if not wiki_page.exists():
            return
        wiki_article_db = self.from_url(wiki_page.fullurl)
        if wiki_article_db != None and (wiki_article_db.status == 'UNINIT' or self.is_expired(wiki_article_db.last_retrieved_date)):
            self.clean_up(wiki_article_db)
            return
        if wiki_article_db == None or self.is_expired(wiki_article_db.last_retrieved_date):
            wiki_article_db = self.init_new_article(wiki_page)
            self.write_article_to_db(wiki_article_db)
            for new_section in wiki_page.sections:
                self.preorder_section(wiki_article_db, new_section, None)
            #self.mark_completed(wiki_article_db)

if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == "download":
        doc_name = sys.argv[2]
        etl = WikiRadioETL()
        etl.download_article(doc_name)