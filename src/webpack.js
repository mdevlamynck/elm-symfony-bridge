const { execSync } = require('child_process');
const fs = require('fs');
const mkdirp = require('mkdirp');
const path = require('path');
const glob = require('glob');
const Elm = require('./Main.elm');

class ElmSymfonyBridgePlugin {
    constructor(options) {
        if (typeof options.dev === 'undefined') {
            throw new Error('You must configure the dev option, it must be true when building for the dev env and false when building for the prod env');
        }

        this.dev = options.dev === true;
        this.urlPrefix = this.ifDefined(options.urlPrefix, '/app_dev.php');
        this.elmRoot = this.ifDefined(options.elmRoot, './assets/elm');
    }

    apply(compiler) {
        this.transpiler = Elm.Main.worker();
        this.hasAlreadyRun = false;

        // Run symfony dumps commands at the beginning of every compilation
        compiler.plugin('before-compile', (compilationParameters, callback) => {
            if (this.hasAlreadyRun) {
                callback();
                return;
            }

            this.hasAlreadyRun = true;

            this.chain(
                [
                    this.transpileRouting,
                    this.transpileTranslations
                ],
                callback
            );
        });

        // Trigger recompilation via watching symfony files
        // Only needed to be enabled after the first compilation
        compiler.plugin('after-compile', (compilation, callback) => {
            this.hasAlreadyRun = false;

            let dirs = compilation.contextDependencies;

            this.arrayAddIfNotPresent(dirs, 'src');
            this.arrayAddIfNotPresent(dirs, 'app');

            compilation.contextDependencies = dirs;

            callback();
        });
    }

    transpileRouting (callback) {
        const content = execSync('./bin/console debug:router --format=json');

        const that = this;
        this.transpiler.ports.sendToJs.subscribe(function (data) {
            that.onSuccess(data, function() {
                that.writeIfChanged(that.elmRoot + '/Routing.elm', data.content);
            });

            that.transpiler.ports.sendToJs.unsubscribe(this);
            callback();
        });

        this.transpiler.ports.sendToElm.send({
            routing: {
                urlPrefix: this.dev ? this.urlPrefix : '',
                content: content
            }
        });
    }

    transpileTranslations(callback) {
        execSync('./bin/console bazinga:js-translation:dump --env=prod');

        const that = this;
        const files = glob.sync('./web/js/translations/*/fr.json');

        this.chain(
            files.map(file => {
                return (callback) => {
                    this.transpiler.ports.sendToJs.subscribe(function (data) {
                        that.onSuccess(data, function() {
                            that.makeDir(that.elmRoot + '/Trans');
                            that.writeIfChanged(that.elmRoot + '/' + data.file.name, data.file.content);
                        });

                        that.transpiler.ports.sendToJs.unsubscribe(this);
                        callback();
                    });

                    const content = fs.readFileSync(file, 'utf8');
                    that.transpiler.ports.sendToElm.send({
                        translation: {
                            name: file,
                            content: content
                        }
                    });
                };
            }),
            callback
        );
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
        if (!array.includes(value)) {
            array.push(value);
        }
    }

    ifDefined(value, defaultValue) {
        return (typeof value !== 'undefined' && value !== null) ? value : defaultValue;
    }

    onSuccess(data, callback) {
        if (data.succeeded) {
            callback();
        } else {
            console.log(data.error);
        }
    }

    chain(functions, callback) {
        if (functions.length === 0) {
            callback();
            return;
        }

        const head = functions[0];
        const tail = functions.slice(1);

        const that = this;
        head(function() { that.chain(tail, callback)});
    }
}

module.exports = ElmSymfonyBridgePlugin;
