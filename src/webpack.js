const { execSync } = require('child_process');
const fs = require('fs');
const mkdirp = require('mkdirp');
const path = require('path');
const glob = require('glob');
const validateOptions = require('schema-utils');
const schema = require('./schema.json');
const ElmWorker = require('./Main.elm').Elm.Main;

class ElmSymfonyBridgePlugin {
    constructor(options) {
        validateOptions(schema, options, 'elm-symfony-bridge');
        this.options = options;

        this.transpiler = ElmWorker.init();
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
                this.arrayAddIfNotPresent(dirs, 'src');
                this.arrayAddIfNotPresent(dirs, 'app');

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
            const content = this.runSymfonyCommand('debug:router --format=json');

            const that = this;
            const elmSubscribtion = function (data) {
                that.onSuccess("routing", data, function() {
                    that.writeIfChanged(that.options.elmRoot + '/Routing.elm', data.content);
                });

                that.transpiler.ports.sendToJs.unsubscribe(elmSubscribtion);
                callback();
            };

            this.transpiler.ports.sendToJs.subscribe(elmSubscribtion);
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
            this.runSymfonyCommand('bazinga:js-translation:dump ' + this.options.outputFolder + '/js');

            const files = glob.sync('./' + this.options.outputFolder + '/js/translations/*/' + this.options.lang + '.json');
            let remainingTranslations = files.length;

            const that = this;
            const elmSubscribtion = function (data) {
                that.onSuccess("translation", data, function() {
                    that.makeDir(that.options.elmRoot + '/Trans');
                    that.writeIfChanged(that.options.elmRoot + '/' + data.file.name, data.file.content);
                });

                remainingTranslations--;
                if (remainingTranslations === 0) {
                    that.transpiler.ports.sendToJs.unsubscribe(elmSubscribtion);
                    callback();
                }
            };

            this.transpiler.ports.sendToJs.subscribe(elmSubscribtion);
            files.map(file => {
                const content = fs.readFileSync(file, 'utf8');
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

    makeDir(dir) {
        try {
            mkdirp.sync(dir);
        } catch (err) {
            if (err.code !== 'EEXIST') {
                throw err
            }
        }
    }

    writeIfChanged(filePath, content) {
        try {
            const existingContent = fs.readFileSync(filePath, 'utf8');

            if (content !== existingContent) {
                this.writeFile(filePath, content);
            }
        } catch (err) {
            this.writeFile(filePath, content);
        }
    }

    writeFile(filePath, content) {
        this.makeDir(path.dirname(filePath));
        fs.writeFileSync(filePath, content);
    }

    arrayAddIfNotPresent(array, value) {
        // Webpack 4.x
        if (typeof array.add !== 'undefined') {
            // This is actually a Set in webpack 4 so we don't need check the presence of `value` in `array`.
            array.add(value);
        }
        // Webpack 3.x
        else if (!array.includes(value)) {
            array.push(value);
        }
    }

    onSuccess(type, data, callback) {
        if (data.type === type && data.succeeded === true) {
            callback();
        } else if (data.succeeded === true) {
            console.log("Expected " + type + " got " + data.type + ".");
        } else {
            console.log(data.error);
        }
    }

    runSymfonyCommand(command) {
        return execSync(
            './bin/console ' + command + ' --env=' + (this.options.dev ? 'dev' : 'prod'),
            {encoding: 'utf8'}
        );
    }
}

module.exports = ElmSymfonyBridgePlugin;
