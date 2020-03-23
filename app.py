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

# Implement singleton to avoid global objects
class ConnectionManager(object):    
    __instance = None
    __connection = None
    __lock = Lock()

    def __new__(cls):
        if ConnectionManager.__instance is None:
            ConnectionManager.__instance = object.__new__(cls)        
        return ConnectionManager.__instance       
    
    def __getConnection(self):
        if (self.__connection == None):
            application_name = ";APP={0}".format(socket.gethostname())  
            self.__connection = pyodbc.connect(os.environ['SQLAZURECONNSTR_RLS'] + application_name)                  
        
        return self.__connection

    def __removeConnection(self):
        self.__connection = None

    @retry(stop=stop_after_attempt(3), wait=wait_fixed(10), retry=retry_if_exception_type(pyodbc.OperationalError), after=after_log(app.logger, logging.DEBUG))
    def executeQueryJSON(self, procedure, username, payload=None):
        result = {}  
        try:
            conn = self.__getConnection()

            cursor = conn.cursor()

            # set session context info, used by Row-Level Security
            cursor.execute(f"EXEC sys.sp_set_session_context @key=N'username', @value=?, @read_only=0;", username)

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
        except pyodbc.OperationalError as e:            
            app.logger.error(f"{e.args[1]}")
            if e.args[0] == "08S01":
                # If there is a "Communication Link Failure" error, 
                # then connection must be removed
                # as it will be in an invalid state
                self.__removeConnection() 
                raise                        
        finally:
            cursor.close()
                         
        return result

class Queryable(Resource):
    def get(self):  
        args = parser.parse_args()
        result = self.executeQueryJson("get", args["X-UserName"])   
        return result, 200

    def executeQueryJson(self, verb, username, payload=None):
        result = {}  
        entity = type(self).__name__.lower()
        procedure = f"web.{verb}_{entity}"
        result = ConnectionManager().executeQueryJSON(procedure, username, payload)
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
