import ElmWorker from '../src/Main.elm';
import fs from '../src/filesystem.js';
import glob from 'glob';
import schema from './schema.json';
import symfony from '../src/symfony.js';
import utils from '../src/utils.js';
import validateOptions from 'schema-utils';

const watchedFolders = ['src', 'app', 'config'];

class ElmSymfonyBridgePlugin {

    constructor(options) {
        validateOptions(schema, options, 'elm-symfony-bridge');

        this.options = options;
        utils.setDefaultValueIfAbsent(options, 'outputFolder', 'public');
        utils.setDefaultValueIfAbsent(options, 'elmRoot', './assets/elm');
        utils.setDefaultValueIfAbsent(options, 'elmVersion', '0.19');
        utils.setDefaultValueIfAbsent(options, 'enableRouting', true);
        utils.setDefaultValueIfAbsent(options, 'lang', 'en');
        utils.setDefaultValueIfAbsent(options, 'enableTranslations', true);
        utils.setDefaultValueIfAbsent(options, 'urlPrefix', '/index.php');

        this.transpiler = ElmWorker.Elm.Main.init();
        this.hasAlreadyRun = false;
    }

    apply(compiler) {
        // Run symfony dumps commands at the beginning of every compilation
        var beforeCompile = (compilationParameters, callback) => {
            if (this.hasAlreadyRun) {
                callback();
                return;
            }

            this.hasAlreadyRun = true;

            const that = this;
            this.transpileRouting(function () {
                that.transpileTranslations(callback);
            });
        };

        // Trigger recompilation via watching symfony files
        // Only needed to be enabled after the first compilation
        var afterCompile = (compilation, callback) => {
            this.hasAlreadyRun = false;

            let dirs = compilation.contextDependencies;

            if (typeof dirs !== 'undefined') {
                watchedFolders.forEach((folder) => {
                    utils.arrayPushIfNotPresent(dirs, folder);
                });

                compilation.contextDependencies = dirs;
            }

            callback();
        };

        // Webpack 4.x
        if (typeof compiler.hooks !== 'undefined') {
            compiler.hooks.beforeCompile.tapAsync('ElmSymfonyBridgePlugin', beforeCompile);
            compiler.hooks.afterCompile.tapAsync('ElmSymfonyBridgePlugin', afterCompile);
        }
        // Webpack 3.x
        else {
            compiler.plugin('before-compile', beforeCompile);
            compiler.plugin('after-compile', afterCompile);
        }
    }

    transpileRouting (callback) {
        if (this.options.enableRouting) {
            const content = symfony.runCommand('debug:router --format=json', this.options.dev);

            const that = this;
            const elmSubscription = function (data) {
                utils.onSuccess('routing', data, function() {
                    fs.writeIfChanged(that.options.elmRoot + '/Routing.elm', data.content);
                });

                that.transpiler.ports.sendToJs.unsubscribe(elmSubscription);
                callback();
            };

            this.transpiler.ports.sendToJs.subscribe(elmSubscription);
            this.transpiler.ports.sendToElm.send({
                routing: {
                    urlPrefix: this.options.dev ? this.options.urlPrefix : '',
                    content: content,
                    version: this.options.elmVersion
                }
            });
        } else {
            callback();
        }
    }

    transpileTranslations(callback) {
        if (this.options.enableTranslations) {
            symfony.runCommand('bazinga:js-translation:dump ' + this.options.outputFolder + '/js', this.options.dev);

            const files = glob.sync('./' + this.options.outputFolder + '/js/translations/*/' + this.options.lang + '.json');
            let remainingTranslations = files.length;

            const that = this;
            const elmSubscription = function (data) {
                utils.onSuccess('translation', data, function() {
                    fs.writeIfChanged(that.options.elmRoot + '/' + data.file.name, data.file.content);
                });

                remainingTranslations--;
                if (remainingTranslations === 0) {
                    that.transpiler.ports.sendToJs.unsubscribe(elmSubscription);
                    callback();
                }
            };

            this.transpiler.ports.sendToJs.subscribe(elmSubscription);
            files.map(file => {
                const content = fs.readFile(file);
                that.transpiler.ports.sendToElm.send({
                    translation: {
                        name: file,
                        content: content,
                        version: this.options.elmVersion
                    }
                });
            });
        } else {
            callback();
        }
    }
}

module.exports = ElmSymfonyBridgePlugin;
