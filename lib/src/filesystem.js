import fs from 'node:fs/promises';
import path from 'node:path';
import utils from './utils.js';

async function exists(filePath) {
    return await fs.exists(filePath);
}

async function makeDir(dir) {
    try {
        await fs.mkdir(dir, { recursive: true });
    } catch (err) {
        if (err.code !== 'EEXIST') {
            throw err
        }
    }
}

async function writeFile(filePath, content) {
    await makeDir(path.dirname(filePath));
    await fs.writeFile(filePath, content);
}

async function writeIfChanged(filePath, content) {
    try {
        const existingContent = await readFile(filePath);

        if (content !== existingContent) {
            await writeFile(filePath, content);
        }
    } catch (err) {
        await writeFile(filePath, content);
    }
}

async function readFile(filePath) {
    return await fs.readFile(filePath, 'utf8');
}

async function readJsonFile(filePath) {
    return JSON.parse(await readFile(filePath));
}

async function editJsonFile(filePath, callback) {
    try {
        const content = await readJsonFile(filePath);
        const newContent = callback(content);

        await writeIfChanged(filePath, JSON.stringify(newContent, null, 4));
    } catch (e) {
        utils.error('Failed to edit ' + filePath, e);
    }
}

function resolve(folder, options) {
    return path.resolve(options.projectRoot, folder);
}

function parse(file) {
    return path.parse(file);
}

module.exports = {
    exists,
    writeIfChanged,
    readFile,
    readJsonFile,
    editJsonFile,
    resolve,
    parse,
};
