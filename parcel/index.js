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
            generatedCodeFolder: 'elm-stuff/generated-code/elm-symfony-bridge',
            tmpFolder: 'elm-stuff/generated-code/elm-symfony-bridge',
            elmVersion: '0.19',
            enableRouting: true,
            urlPrefix: '/index.php',
            enableTranslations: false,
            lang: 'en',
        }
    };
    loadConfig(global);

    if (global.options.watch) {
        const regenerateWatches = utils.combinations(
			['src', 'app', 'config'],
			['php', 'yaml', 'yml', 'xml'],
			(folder, extension) => folder + '/**/*.' + extension
		);

        const reloadConfigWatches = ['elm.json', 'elm-package.json', 'package.json', 'composer.json'];

        chokidar.watch(regenerateWatches, { ignoreInitial: true }).on('all', () => generate(global));
        chokidar.watch(reloadConfigWatches, { ignoreInitial: true }).on('all', () => reloadConfig(global));
    }

    generate(global);
}

function loadConfig(global) {
    global.options = utils.overrideDefaultsIfProvided(config.guessImplicit(global), global.options);
    global.options = utils.overrideDefaultsIfProvided(config.readExplicit(), global.options);
}

function generate(global) {
    prepareFolderForGeneratedCode(global);
    routing.transpile(global);
    translations.transpile(global);
}

function prepareFolderForGeneratedCode(global) {
    const file = global.options.elmVersion === '0.19' ? 'elm.json' : 'elm-package.json';
    fs.editJsonFile(file, (elmConfig) => {
        return utils.mapKey(elmConfig, 'source-directories', (sources) => {
            return utils.arrayPushIfNotPresent(sources, global.options.generatedCodeFolder);
        });
    });
}

function reloadConfig(global) {
    loadConfig(global);
    generate(global);
}

module.exports = run;
