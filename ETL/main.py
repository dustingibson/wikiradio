from flask import Flask, request
from wiki import WikiRadioETL
app = Flask (__name__)

@app.route("/")
def run():
    query = request.args.get('q', 'No query provided')
    mode = request.args.get('mode')
    keyword = request.args.get('keyword')
    try:
        etl = WikiRadioETL()
        if mode == "download":
            doc_name = keyword
            article = etl.download_article(doc_name)
            stdout = "~{}~{}~{}".format(article.id, article.version, article.title) if article != None else "~~~"
            return stdout
        elif mode == "search":
            title = etl.search_online(keyword)
            return title
    except Exception as e:
        pass