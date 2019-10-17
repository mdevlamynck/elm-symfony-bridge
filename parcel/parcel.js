const ElmWorker = require('../src/Main.elm').Elm.Main;

module.exports = function(bundler) {
    bundler.on('buildStart', entryPoints => {
        // TODO
        this.transpiler = ElmWorker.init();
    });
}
