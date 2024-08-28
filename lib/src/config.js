import dotenv from 'dotenv';
import fs from './filesystem.js';
import { glob } from 'glob';
import symfony from './symfony.js';
import utils from './utils.js';

async function guessImplicit(global) {
    return {
        elmVersion: await fs.exists('elm.json') ? '0.19' : (await fs.exists('elm-package.json') ? '0.18' : null),
        enableTranslations: symfony.hasBazingaJsTranslationBundle(global.options),
        lang: symfony.queryConfig('kernel.default_locale', global.options),
        urlPrefix: await guessUrlPrefix()
    };
}

async function guessUrlPrefix() {
    let filePath = await glob('{public/index,web/app_dev}.php')[0] || null;
    return filePath !== null
        ? '/' + fs.parse(filePath).base
        : null;
}

async function readExplicit() {
    try {
        return await fs.readJsonFile('package.json')['elm-symfony-bridge'] || {};
    } catch (e) {
        error('Failed to read package.json, unable to load explicit configuration.', e);
        return {};
    }
}

function loadEnvVariables(global) {
    let envVars = readEnvVariables(global.options);

    Object.entries(global.options.envVariables).forEach(([key, value]) => {
        global.options.envVariables[key] = envVars[value] || null;
    });
}

function readEnvVariables(options) {
    let env = dotenv.config({ path: fs.resolve('./.env', options) }).parsed;
    let localEnv = dotenv.config({ path: fs.resolve('./.env.local', options) }).parsed;

    return utils.merge(localEnv, env);
}

module.exports = {
    guessImplicit,
    readExplicit,
    loadEnvVariables,
};
