// Simple Node.js script to test Firebase connection
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = {
  "type": "service_account",
  "project_id": "workmate-gh",
  "private_key_id": "",
  "private_key": "",
  "client_email": "",
  "client_id": "",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs"
};

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://workmate-gh.firebaseio.com'
});

async function testFirebase() {
  try {
    // Test Firestore connection
    const db = admin.firestore();
    const users = await db.collection('users').limit(1).get();
    console.log('Firestore connection successful');
    console.log('Users found:', users.size);

    // Test Auth connection
    const auth = admin.auth();
    const usersList = await auth.listUsers(10);
    console.log('Auth connection successful');
    console.log('Total users:', usersList.users.length);
    
    usersList.users.forEach(user => {
      console.log('User:', user.email, 'UID:', user.uid);
    });

  } catch (error) {
    console.error('Firebase test failed:', error);
  }
}

testFirebase();
