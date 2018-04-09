const { execSync } = require('child_process');
const fs = require('fs');
const glob = require('glob')
const Elm = require('./Main.elm');

class ElmSymfonyBridgePlugin {

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

			execSync('./bin/console fos:js-routing:dump --env=prod');
			execSync('./bin/console bazinga:js-translation:dump --env=prod');
			this.transpileTranslations(callback);
		});

		// Trigger recompilation via watching symfony files
		// Only needed to be enabled after the first compilation
		compiler.plugin('after-compile', (compilation, callback) => {
			this.hasAlreadyRun = false;

			var dirs = compilation.contextDependencies;

			this.arrayAddIfNotPresent(dirs, 'src');
			this.arrayAddIfNotPresent(dirs, 'app');

			compilation.contextDependencies = dirs;
		
			callback();
		});
	}

	transpileTranslations(callback) {
		const files = glob.sync('./web/js/translations/*/fr.json');
		var remainingTranslations = files.length;

		var that = this;
		var elmSubscribtion = function(data) {
			if (data.succeeded) {
				that.makeDir('./assets/elm/Trans');
				that.writeIfChanged('./assets/elm/' + data.file.name, data.file.content);
			} else {
				console.log(data.error);
			}

			remainingTranslations--;
			if (remainingTranslations === 0) {
				that.transpiler.ports.sendToJs.unsubscribe(elmSubscribtion);
				callback();
			}
		};

		this.transpiler.ports.sendToJs.subscribe(elmSubscribtion);
		files.map(file => {
			const content = fs.readFileSync(file, 'utf8');
			this.transpiler.ports.sendToElm.send({translation: {name: file, content: content}});
		});
	}

	makeDir(dir) {
		try {
			fs.mkdirSync(dir);
		} catch (err) {
			if (err.code !== 'EEXIST') {
				throw err
			}
		}
	}

	writeIfChanged(path, content) {
		try {
			const existingContent = fs.readFileSync(path, 'utf8');

			if (content !== existingContent) {
				fs.writeFileSync(path, content);
			}
		} catch (err) {
			fs.writeFileSync(path, content);
		}
	}

	arrayAddIfNotPresent(array, value) {
		if (!array.includes(value)) {
			array.push(value);
		}
	}

}

module.exports = ElmSymfonyBridgePlugin;
