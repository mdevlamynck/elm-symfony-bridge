import data from './data.js';
import dotenv from 'dotenv';
import fs from './filesystem.js';
import { glob } from 'glob';
import symfony from './symfony.js';

function loadEnvVariables(global) {
    let envVars = readEnvVariables(global.options);

    Object.entries(global.options.envVariables).forEach(([key, value]) => {
        global.options.envVariables[key] = envVars[value] || null;
    });
}

function readEnvVariables(options) {
    let env = dotenv.config({ path: fs.resolve('./.env', options) }).parsed;
    let localEnv = dotenv.config({ path: fs.resolve('./.env.local', options) }).parsed;

    return data.merge(localEnv, env);
}

module.exports = {
    loadEnvVariables,
};
