import dotenv from 'dotenv';
import fs from './filesystem.js';
import glob from 'glob';
import path from 'path';
import symfony from './symfony.js';
import utils from './utils.js';

function guessImplicit(global) {
    return {
        elmVersion: fs.exists('elm.json') ? '0.19' : (fs.exists('elm-package.json') ? '0.18' : null),
        enableTranslations: symfony.hasBazingaJsTranslationBundle(global.options.dev),
        lang: symfony.queryConfig('kernel.default_locale', global.options.dev),
        urlPrefix: guessUrlPrefix()
    };
}

function guessUrlPrefix() {
    let filePath = glob.sync('{public/index,web/app_dev}.php')[0] || null;
    return filePath !== null
        ? '/' + path.parse(filePath).base
        : null;
}

function readExplicit() {
    try {
        return fs.readJsonFile('package.json')['elm-symfony-bridge'] || {};
    } catch (e) {
        error('Failed to read package.json, unable to load explicit configuration.', e);
        return {};
    }
}

function loadEnvVariables(global) {
    let envVars = readEnvVariables();

    Object.entries(global.options.envVariables).forEach(([key, value]) => {
        global.options.envVariables[key] = envVars.parsed[value] || null;
    });
}

function readEnvVariables() {
    let env = dotenv.config({ path: './.env' })
    let localEnv = dotenv.config({ path: './.env.local' })

    return utils.merge(localEnv, env);
}

module.exports = {
    guessImplicit,
    readExplicit,
    loadEnvVariables,
};
