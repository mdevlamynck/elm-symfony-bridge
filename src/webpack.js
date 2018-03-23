const { execSync } = require('child_process');
const Elm = require('./Main.elm');

class ElmSymfonyBridgePlugin {
	apply(compiler) {
		var transpiler = Elm.Main.worker();

		//transpiler.ports.sendToElm.send({translation: ""});
		//transpiler.ports.sendToJs.subscribe(data => data.translation);

		// Run symfony dumps commands at the beginning of every compilation
		compiler.plugin('compilation', compilation => {
			execSync('./bin/console fos:js-routing:dump');
			execSync('./bin/console bazinga:js-translation:dump');
		});

		// Trigger recompilation via watching symfony files
		compiler.plugin('after-compile', (compilation, callback) => {
			var dirs = compilation.contextDependencies;

			if (!dirs.includes('src')) {
				dirs.push('src');
				compilation.contextDependencies = dirs;
			}
		
			callback();
		});
	}
}

module.exports = ElmSymfonyBridgePlugin;