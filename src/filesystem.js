import fs from 'fs';
import mkdirp from 'mkdirp';
import path from 'path';
import utils from './utils.js';

function exists(filePath) {
    return fs.existsSync(filePath);
}

function makeDir(dir) {
    try {
        mkdirp.sync(dir);
    } catch (err) {
        if (err.code !== 'EEXIST') {
            throw err
        }
    }
}

function writeFile(filePath, content) {
    makeDir(path.dirname(filePath));
    fs.writeFileSync(filePath, content);
}

function writeIfChanged(filePath, content) {
    try {
        const existingContent = readFile(filePath);

        if (content !== existingContent) {
            writeFile(filePath, content);
        }
    } catch (err) {
        writeFile(filePath, content);
    }
}

function readFile(filePath) {
    return fs.readFileSync(filePath, 'utf8');
}

function readJsonFile(filePath) {
    return JSON.parse(readFile(filePath));
}

function editJsonFile(filePath, callback) {
    try {
        const content = readJsonFile(filePath);
        const newContent = callback(content);

        writeIfChanged(filePath, JSON.stringify(newContent, null, 4));
    } catch (e) {
        utils.error('Failed to edit ' + filePath, e);
    }
}

module.exports = {
    exists,
    writeIfChanged,
    readFile,
    readJsonFile,
    editJsonFile
};
