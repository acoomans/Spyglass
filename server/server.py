from flask import Flask, request
from termcolor import colored
import json, base64, pprint

pp = pprint.PrettyPrinter(indent=4)

app = Flask(__name__)
app.debug = True

@app.route("/api/1/track/events/", methods=['POST'])
def hello():
	print colored("\n%s %s" % (request.method, request.path), 'green')
	print request.headers
	data = base64.b64decode(request.form['data'])
	pp.pprint(json.loads(data))
	print "\n"
	
	return json.dumps({
		'result': "ok",
		'code': 0
	})

if __name__ == "__main__":
	app.run(port=5403)