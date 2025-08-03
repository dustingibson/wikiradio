import os
from flask import Flask, request
from wiki import WikiRadioETL
from werkzeug.utils import secure_filename
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

@app.route('/upload', methods=['POST'])
def upload():
    try:
        if 'file' in request.files:
            print("There are files")
        etl = WikiRadioETL()
        upload_directory = etl.directory
        file = request.files['file']
        file.save(os.path.join(upload_directory , secure_filename(file.filename)))
        return "Success"
    except Exception as e:
        return "Error"
    
@app.route('/test_upload', methods=['GET'])
def test_upload():
    fname = request.args.get('file_path')
    etl = WikiRadioETL()
    etl.upload(fname)
    return "Success"