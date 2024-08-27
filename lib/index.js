import config from './src/config.js';
import fs from './src/filesystem.js';
import routing from './src/routing.js';
import translations from './src/translations.js';
import utils from './src/utils.js';
import ElmWorker from './src/Main.elm';

module.exports = {
    config: config,
    fs: fs,
    routing: routing,
    translations: translations,
    utils: utils,
    ElmWorker: ElmWorker
};
