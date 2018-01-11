#!/usr/bin/env python

import sys, os, socket, re, subprocess

reload(sys)
sys.setdefaultencoding('utf8')

installpath = os.path.abspath(os.path.dirname(sys.argv[0]))
sys.path.append(installpath + '/python')

from tendo import singleton
me = singleton.SingleInstance()

HOST = ''
PORT = 8282

for arg in sys.argv:
	arg_arr = arg.rsplit('=', 1)
	
	if arg_arr[0] == "ip":
		HOST = arg_arr[1]
	
	if arg_arr[0] == "port":
		PORT = int(arg_arr[1])

		
listen_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
listen_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
listen_socket.bind((HOST, PORT))
listen_socket.listen(1)

scriptPath = os.path.abspath(os.path.dirname(sys.argv[0])) # script path
scriptParent = os.path.abspath(os.path.join(scriptPath, os.pardir)) # parent path (bash loader base)

if not HOST:
	print('Webserver auf Port %s gestartet!' % PORT)
else:
	print('Webserver auf mit IP ' + HOST + ' und Port %s gestartet!' % PORT)

def post_file(file, req):
    
    file = file.strip('/')
    file_split = file.rsplit('?', 1)
    file_only = file_split[0]
    
    if(len(file_split) == 2):
        file_args = file_split[1]
    else:
        file_args = ""
    
    if(os.path.isfile(scriptPath + '/status/' + file_only)):
        file_ext = file_only.rsplit('.', 1)
        file_ext = file_ext[1]
        
        if file_ext == "php":
			data = os.popen('CONTENT_LENGTH=1000; php-cgi -c "' + scriptPath + '" "' + scriptPath + '/status/' + file + ' ' + req + '"').read()
			data = unicode(data, "utf-8")
			output = """\
HTTP/1.1 200 OK
Content-Type: application/octet-stream
""" + data

    return output

def load_file(file):

    file = file.strip('/')
    file_split = file.rsplit('?', 1)
    file_only = file_split[0]
    
    if(len(file_split) == 2):
        file_args = file_split[1]
    else:
        file_args = ""
    
    if(os.path.isfile(scriptPath + '/status/' + file_only)):
        file_ext = file_only.rsplit('.', 1)
        file_ext = file_ext[1]
		
        content = ""
		
        if file_ext == "html":
            content = "Content-Type: text/html; charset=utf-8"
        elif file_ext == "json":
            content = "Content-Type: application/json"
        elif file_ext == "xml":
            content = "Content-Type: application/xml"
        elif file_ext == "js":
            content = "Content-Type: application/javascript"
        elif file_ext == "txt":
            content = "Content-Type: text/plain"
        elif file_ext == "css":
            content = "Content-Type: text/css"
        elif file_ext == "jpg":
            content = "Content-Type: image/jpeg"
        elif file_ext == "jpeg":
            content = "Content-Type: image/jpeg"
        elif file_ext == "png":
            content = "Content-Type: image/png"
        elif file_ext == "gif":
            content = "Content-Type: image/gif"
        elif file_ext == "woff":
            content = "Content-Type: application/x-font-woff"
        elif file_ext == "ttf":
            content = "Content-Type: font/opentype"
        else:
            content = "Content-Type: application/octet-stream"
	
        if file_ext == "php":
			data = os.popen('php-cgi -c "' + scriptPath + '" "' + scriptPath + '/status/' + file + '"').read()
			data = unicode(data, "utf-8")
			output = """\
HTTP/1.1 200 OK
""" + data
        else:
			with open(scriptPath + '/status/' + file, 'r') as htmlfile:
				data = htmlfile.read()
		
			output = """\
HTTP/1.1 200 OK
""" + content + """\r\n
""" + data

    else:
		output = """\
HTTP/1.1 404 Not Found
Content-Type: text/html; charset=utf-8\r\n
<html><head><title>404 - BASH-Loader</title></head><body><h1>404 - Seite nicht gefunden!</h1></body></html>
"""
	
    return output

def start_loader(cmd):

	print('cmd: ' + cmd)
	print('scriptParent: ' + scriptParent)

	# starte bash loader
	# os.spawnl(os.P_NOWAIT, scriptParent + '/start.sh &')
	process = subprocess.Popen([scriptParent + '/start.sh &'], shell=True, stdin=None, stdout=None, stderr=None, close_fds=True)
	
	output = """\
HTTP/1.1 200 OK
Content-Type: application/json\r\n

{ "BASHLoader" : [ { "version":"$loaderVersion", "start":"ok" } ] }
"""
	return output
	
	
while True:
    client_connection, client_address = listen_socket.accept()
    request = client_connection.recv(2048)
    req = request.decode('utf-8').strip()

    print('req: ' + req)
    
    m = re.search('(GET|POST) (.*) HTTP/1.1', req)
    get_post = m.group(1).strip()
    cmd = m.group(2).strip()
    
    print('get_post: ' + get_post + ' | cmd: ' + cmd)

    if not cmd or cmd == "/" or cmd == "/index.html":
        http_response = load_file('index.html')
    elif cmd == "/status" or cmd == "/status/" or cmd == "/status.json":
        http_response = load_file('status.json')
    elif cmd.startswith('/start'):
        http_response = start_loader(cmd)
    elif get_post == "POST":
        http_response = post_file(cmd, req)
    else:
        http_response = load_file(cmd)

    client_connection.sendall(http_response)
    client_connection.close()
	

	