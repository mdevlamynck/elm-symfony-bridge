import ElmWorker from '../src/Main.elm';
import config from '../src/config.js';
import fs from '../src/filesystem.js';
import routing from '../src/routing.js';
import schema from './schema.json';
import symfony from '../src/symfony.js';
import translations from '../src/translations.js';
import utils from '../src/utils.js';
import { validate } from 'schema-utils';

const watchedFolders = ['src', 'app', 'config', 'translations'];

class ElmSymfonyBridgePlugin {

    constructor(options) {
        validate(schema, options, 'elm-symfony-bridge');

        this.options = options;
        utils.setDefaultValueIfAbsent(options, 'outputFolder', './elm-stuff/generated-code/elm-symfony-bridge');
        utils.setDefaultValueIfAbsent(options, 'projectRoot', './');
        utils.setDefaultValueIfAbsent(options, 'elmRoot', './assets/elm');
        utils.setDefaultValueIfAbsent(options, 'elmVersion', '0.19');
        utils.setDefaultValueIfAbsent(options, 'enableRouting', true);
        utils.setDefaultValueIfAbsent(options, 'lang', 'en');
        utils.setDefaultValueIfAbsent(options, 'enableTranslations', true);
        utils.setDefaultValueIfAbsent(options, 'urlPrefix', '/index.php');
        utils.setDefaultValueIfAbsent(options, 'envVariables', {});
        config.loadEnvVariables(this);

        this.transpiler = ElmWorker.Elm.Main.init();
    }

    apply(compiler) {
        const that = this;

        var compile = (compilation, compilationParams) => {
            try {
                routing.transpile(that);
                translations.transpile(that);
            } catch (error) {
                compilation.errors.push(error);
            }
        };

        var addDirsToWatch = (compilation) => {
            let dirs = compilation.contextDependencies;

            if (typeof dirs !== 'undefined') {
                watchedFolders.forEach(folder => {
                    compilation.contextDependencies.add(fs.resolve(folder, that.options));
                });
            }
        }

        compiler.hooks.compilation.tap('ElmSymfonyBridgePlugin', compile);
        compiler.hooks.afterCompile.tap('ElmSymfonyBridgePlugin', addDirsToWatch);
    }

}

module.exports = ElmSymfonyBridgePlugin;
