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
import jwt

# Initialize Flask
app = Flask(__name__)

# Setup Flask Restful framework
api = Api(app)
parser = reqparse.RequestParser()
parser.add_argument('Authorization', location='headers')

# Set connection string
application_name = ";APP={0}".format(socket.gethostname())  
connection_string = os.environ['SQLAZURECONNSTR_RLS'] + application_name

class Queryable(Resource):
    def __authorize(self):
        encoded = ""
        user_hash_id = 0
        
        request_args = parser.parse_args()
        authorization = request_args["Authorization"]
        tokens = authorization.split()

        if tokens[0].lower() == "bearer":
            encoded = tokens[1]
        else:
            raise Exception("Wrong authorization schema")
        
        try:
            secure_payload = jwt.decode(encoded, 'mySUPERs3cr3t', algorithms=['HS256'])        
            user_hash_id = int(secure_payload["user-hash-id"])
        except jwt.InvalidSignatureError:
            user_hash_id = 0
        except:
            raise

        return user_hash_id

    def get(self):      
        user_hash_id = self.__authorize()
        result = self.executeQueryJson("get", user_hash_id)   
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
            cursor.execute(f"EXEC sys.sp_set_session_context @key=N'user-hash-id', @value=?, @read_only=1;", username)                    

            if payload:
                print("EXEC %s %s" % (procedure, json.dumps(payload)))
                cursor.execute(f"EXEC {procedure} ?", json.dumps(payload))
            else:
                print("EXEC %s" % procedure)
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
api.add_resource(EvenMoreSensitiveData, '/sensitive-data/more')
