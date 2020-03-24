import sys
import os
import json
import pyodbc
import socket
from flask import Flask
from flask_restful import reqparse, abort, Api, Resource
from threading import Lock
from tenacity import *
import logging

# Initialize Flask
app = Flask(__name__)

# Setup Flask Restful framework
api = Api(app)
parser = reqparse.RequestParser()
parser.add_argument('X-UserName', location='headers')

# Set connection string
application_name = ";APP={0}".format(socket.gethostname())  
connection_string = os.environ['SQLAZURECONNSTR_RLS'] + application_name

class Queryable(Resource):
    def get(self):  
        args = parser.parse_args()
        result = self.executeQueryJson("get", args["X-UserName"])   
        return result, 200

    @retry(stop=stop_after_attempt(3), wait=wait_fixed(10), retry=retry_if_exception_type(pyodbc.OperationalError), after=after_log(app.logger, logging.DEBUG))
    def executeQueryJson(self, verb, username, payload=None):
        result = {}  
        entity = type(self).__name__.lower()
        procedure = f"web.{verb}_{entity}"
        
        result = {}  
        try:            
            conn = pyodbc.connect(connection_string)
            cursor = conn.cursor()

            # set session context info, used by Row-Level Security
            cursor.execute(f"EXEC sys.sp_set_session_context @key=N'username', @value=?, @read_only=1;", username)

            if payload:
                cursor.execute(f"EXEC {procedure} ?", json.dumps(payload))
            else:
                cursor.execute(f"EXEC {procedure}")

            result = cursor.fetchone()

            if result:
                result = json.loads(result[0])                           
            else:
                result = {}

            cursor.commit()                               
        finally:
            cursor.close()
                                 
        return result

# Customer Class
class SensitiveData(Queryable):
    pass

# Customers Class
class EvenMoreSensitiveData(Queryable):
    pass

# Create API routes
api.add_resource(SensitiveData, '/sensitive-data')
api.add_resource(EvenMoreSensitiveData, '/sensitive-data/super-secret')
