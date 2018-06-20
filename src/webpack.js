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
        this.lang = this.ifDefined(options.lang, 'en');
        this.enableRouting = this.ifDefined(options.enableRouting, true);
        this.enableTranslations = this.ifDefined(options.enableTranslations, true);

        this.transpiler = Elm.Main.worker();
        this.hasAlreadyRun = false;
    }

    apply(compiler) {
        // Run symfony dumps commands at the beginning of every compilation
        compiler.plugin('before-compile', (compilationParameters, callback) => {
            if (this.hasAlreadyRun) {
                callback();
                return;
            }

            this.hasAlreadyRun = true;

            const that = this;
            this.transpileRouting(function () {
                that.transpileTranslations(callback);
            });
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
		if (this.enableRouting) {
			const content = this.runSymfonyCommand('debug:router --format=json');

			const that = this;
			const elmSubscribtion = function (data) {
				that.onSuccess("routing", data, function() {
					that.writeIfChanged(that.elmRoot + '/Routing.elm', data.content);
				});

				that.transpiler.ports.sendToJs.unsubscribe(elmSubscribtion);
				callback();
			};

			this.transpiler.ports.sendToJs.subscribe(elmSubscribtion);
			this.transpiler.ports.sendToElm.send({
				routing: {
					urlPrefix: this.dev ? this.urlPrefix : '',
					content: content
				}
			});
		} else {
			callback();
		}
    }

    transpileTranslations(callback) {
		if (this.enableTranslations) {
			this.runSymfonyCommand('bazinga:js-translation:dump');

			const files = glob.sync('./web/js/translations/*/' + this.lang + '.json');
			let remainingTranslations = files.length;

			const that = this;
			const elmSubscribtion = function (data) {
				that.onSuccess("translation", data, function() {
					that.makeDir(that.elmRoot + '/Trans');
					that.writeIfChanged(that.elmRoot + '/' + data.file.name, data.file.content);
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
						content: content
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
        if (!array.includes(value)) {
            array.push(value);
        }
    }

    ifDefined(value, defaultValue) {
        return (typeof value !== 'undefined' && value !== null) ? value : defaultValue;
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
        return execSync('./bin/console ' + command + ' --env=' + (this.dev ? 'dev' : 'prod'), {encoding: 'utf8'});
	}
}

module.exports = ElmSymfonyBridgePlugin;
