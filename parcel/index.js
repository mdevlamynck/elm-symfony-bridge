import ElmWorker from '../src/Main.elm';
import chokidar from 'chokidar';
import config from '../src/config.js';
import fs from '../src/filesystem.js';
import routing from '../src/routing.js';
import translations from '../src/translations.js';
import utils from '../src/utils.js';

function run(bundler) {
    const global = {
        transpiler: ElmWorker.Elm.Main.init(),
        options: {
            watch: bundler.options.watch,
            dev: !bundler.options.production,
            projectRoot: './',
            elmRoot: './elm-stuff/generated-code/elm-symfony-bridge',
            outputFolder: './elm-stuff/generated-code/elm-symfony-bridge',
            elmVersion: '0.19',
            enableRouting: true,
            urlPrefix: '/index.php',
            enableTranslations: false,
            lang: 'en',
            watchFolders: ['src', 'app', 'config', 'translations'],
            watchExtensions: ['php', 'yaml', 'yml', 'xml'],
            watchConfig: ['elm.json', 'elm-package.json', 'package.json', 'composer.json'],
            envVariables: {},
        }
    };
    loadConfig(global);

    if (global.options.watch) {
        const regenerateWatches = utils.combinations(
            global.options.watchFolders,
            global.options.watchExtensions,
            (folder, extension) => fs.resolve(folder, global.options) + '/**/*.' + extension
        );

        chokidar.watch(regenerateWatches, { ignoreInitial: true }).on('all', () => generate(global));
        chokidar.watch(global.options.watchConfig, { ignoreInitial: true }).on('all', () => reloadConfig(global));
    }

    generate(global);
}

function loadConfig(global) {
    global.options = utils.overrideDefaultsIfProvided(config.guessImplicit(global), global.options);
    global.options = utils.overrideDefaultsIfProvided(config.readExplicit(), global.options);

    config.loadEnvVariables(global);
}

function generate(global) {
    prepareFolderForGeneratedCode(global);
    routing.transpile(global);
    translations.transpile(global);
}

function prepareFolderForGeneratedCode(global) {
    const file = global.options.elmVersion === '0.19' ? 'elm.json' : 'elm-package.json';
    fs.editJsonFile(file, elmConfig => {
        return utils.mapKey(elmConfig, 'source-directories', sources => {
            return utils.arrayPushIfNotPresent(sources, global.options.elmRoot);
        });
    });
}

function reloadConfig(global) {
    loadConfig(global);
    generate(global);
}

module.exports = run;
