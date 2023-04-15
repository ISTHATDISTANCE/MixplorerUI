import firebase_admin
from firebase_admin import credentials, storage, db

cred = credentials.Certificate('mixplorer-98aed-firebase-adminsdk-l3o4x-7045d7c8d6.json')
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://mixplorer-98aed-default-rtdb.firebaseio.com/'
})

bucket = storage.bucket('mixplorer-98aed.appspot.com')
imagePath = 'images/snapshots.png'
blob = bucket.blob(imagePath)
localPath = 'snapshots.png'
blob.download_to_filename(localPath)

def listenChanges(event, modelName=""):
    # print(event)
    if event.data:
        print(event.data)
        print(event.event_type)
        print(event.path)

        bucket = storage.bucket('mixplorer-98aed.appspot.com')
        imagePath = 'images/updateRaw.png'
        blob = bucket.blob(imagePath)
        localPath = 'updateRaw.png'
        blob.download_to_filename(localPath)

        if (event.path == "/lamp"):
            sendToFirebase("lamp")
        

        if(event.path == "/chair"):
            sendToFirebase("chair")
        

        if(event.path == "/vase"):
            sendToFirebase("vase")
        

        

        # sendToFirebase()

def sendToFirebase(modelName="", output=[0.5 , 0.5 , 0.5 , 0.5]):
    ref = db.reference()
    ref.update({modelName: output})
    # ref.updateChildValues(["users/123/name": "John", "users/123/age": 30])
    return


# ref = db.reference('/Update')
# ref.listen(listenChanges)

test = db.reference()
test.listen(listenChanges)

# lamp = db.reference('/lamp')
# lamp.listen(listenChanges())

# chair = db.reference('/chair')
# chair.listen(listenChanges())
