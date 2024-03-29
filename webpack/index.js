import ElmWorker from '../src/Main.elm';
import config from '../src/config.js';
import fs from '../src/filesystem.js';
import routing from '../src/routing.js';
import schema from './schema.json';
import symfony from '../src/symfony.js';
import translations from '../src/translations.js';
import utils from '../src/utils.js';
import { validate } from 'schema-utils';

const watchedFolders = ['src', 'app', 'config'];

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
        this.hasAlreadyRun = false;
    }

    apply(compiler) {
        const that = this;

        // Run symfony dumps commands at the beginning of every compilation
        var compilation = (compilation, compilationParams) => {
            if (that.hasAlreadyRun) {
                return;
            }

            that.hasAlreadyRun = true;

            try {
                routing.transpile(that);
                translations.transpile(that);
            } catch (error) {
                compilation.errors.push(error);
            }
        };

        // Trigger recompilation via watching symfony files
        // Only needed to be enabled after the first compilation
        var afterCompile = (compilation, callback) => {
            that.hasAlreadyRun = false;

            let dirs = compilation.contextDependencies;

            if (typeof dirs !== 'undefined') {
                watchedFolders.forEach(folder => {
                    const absolutePath = fs.resolve(folder, that.options);

                    utils.arrayPushIfNotPresent(dirs, absolutePath);
                });

                compilation.contextDependencies = dirs;
            }

            callback();
        };

        // Webpack 4.x
        if (typeof compiler.hooks !== 'undefined') {
            compiler.hooks.compilation.tap('ElmSymfonyBridgePlugin', compilation);
            compiler.hooks.afterCompile.tapAsync('ElmSymfonyBridgePlugin', afterCompile);
        }
        // Webpack 3.x
        else {
            compiler.plugin('compilation', compilation);
            compiler.plugin('after-compile', afterCompile);
        }
    }
}

module.exports = ElmSymfonyBridgePlugin;
