const { execSync } = require('child_process');
const fs = require('fs');
const glob = require('glob')
const Elm = require('./Main.elm');

// TODO handle errors

class ElmSymfonyBridgePlugin {
	construct() {}

	apply(compiler) {
		var transpiler = Elm.Main.worker();

		// Run symfony dumps commands at the beginning of every compilation
		compiler.plugin('before-compile', (compilationParameters, callback) => {
			execSync('./bin/console fos:js-routing:dump');
			execSync('./bin/console bazinga:js-translation:dump');
			transpileTranslations(callback);
		});

		// Trigger recompilation via watching symfony files
		// Only needed to be enabled after the first compilation
		compiler.plugin('after-compile', (compilation, callback) => {
			var dirs = compilation.contextDependencies;

			if (!dirs.includes('src')) {
				dirs.push('src');
				compilation.contextDependencies = dirs;
			}
		
			callback();
		});
	}

	transpileTranslations(callback) {
		const files = glob.sync('./**/Resources/**/translations/*.yml');
		var remainingTranslations = files.length;

		var elmSubscribtion = function(data) {
			if (data.succeeded) {
				fs.writeFileSync('./assets/elm/' + data.file.name, data.file.content);
			} else {
				console.log(data.error);
			}

			remainingTranslations--;
			if (remainingTranslations === 0) {
				transpiler.ports.sendToJs.unsubscribe(elmSubscribtion);
				callback();
			}
		};

		transpiler.ports.sendToJs.subscribe(elmSubscribtion);
		files.map(file => {
			const content = fs.readFileSync(file, 'utf8');
			transpiler.ports.sendToElm.send({translation: content}));
		});
	}
}

module.exports = ElmSymfonyBridgePlugin;
