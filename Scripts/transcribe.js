const fs = require('fs');
const https = require('https');

// DEEPGRAM API KEY
// You can set it here or as an environment variable DEEPGRAM_API_KEY
const API_KEY = process.env.DEEPGRAM_API_KEY || 'YOUR_DEEPGRAM_API_KEY_HERE';

async function transcribe(filePath) {
    if (API_KEY.includes('YOUR_DEEPGRAM')) {
        console.error('Error: Please set your Deepgram API Key in transcribe.js');
        return '';
    }

    return new Promise((resolve, reject) => {
        const audioData = fs.readFileSync(filePath);
        
        const options = {
            hostname: 'api.deepgram.com',
            path: '/v1/listen?smart_format=true&model=nova-2&language=ru',
            method: 'POST',
            headers: {
                'Authorization': `Token ${API_KEY}`,
                'Content-Type': 'audio/m4a',
                'Content-Length': audioData.length
            }
        };

        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                try {
                    const json = JSON.parse(data);
                    const transcript = json.results?.channels[0]?.alternatives[0]?.transcript || '';
                    resolve(transcript);
                } catch (e) {
                    reject(e);
                }
            });
        });

        req.on('error', (e) => reject(e));
        req.write(audioData);
        req.end();
    });
}

const file = process.argv[2];
if (file) {
    transcribe(file)
        .then(text => process.stdout.write(text))
        .catch(err => {
            console.error(err);
            process.exit(1);
        });
}
