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

def listenChanges(event):
    # print(event)
    if event.data:
        print(event.data)
        bucket = storage.bucket('mixplorer-98aed.appspot.com')
        imagePath = 'images/snapshots.png'
        blob = bucket.blob(imagePath)
        localPath = 'snapshots.png'
        blob.download_to_filename(localPath)

        sendToFirebase()

def sendToFirebase():
    output = [1,1,1,1]
    ref = db.reference()
    ref.update({'Suggestions': output})
    # ref.updateChildValues(["users/123/name": "John", "users/123/age": 30])
    return


ref = db.reference('/Update')
ref.listen(listenChanges)
