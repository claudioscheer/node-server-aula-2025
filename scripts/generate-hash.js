const bcrypt = require('bcrypt');

// Get password from command line argument
const password = process.argv[2];

if (!password) {
    console.error('Usage: node hash_password.js <password>');
    console.error('Example: node hash_password.js mypassword123');
    process.exit(1);
}

// Hash the password
const saltRounds = 12;

bcrypt.hash(password, saltRounds)
    .then(hashedPassword => {
        console.log('Original password:', password);
        console.log('Hashed password:', hashedPassword);
    })
    .catch(error => {
        console.error('Error hashing password:', error.message);
        process.exit(1);
    });