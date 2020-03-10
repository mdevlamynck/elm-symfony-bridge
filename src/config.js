import fs from './filesystem.js';
import glob from 'glob';
import path from 'path';
import symfony from './symfony.js';

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

module.exports = {
    guessImplicit,
    readExplicit
};
