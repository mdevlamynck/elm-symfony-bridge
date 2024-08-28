import { ElmWorker, config, fs, routing, translations, utils } from 'elm-symfony-bridge-lib';
import schema from './schema.json';
import { validate } from 'schema-utils';

const watchedDirs = ['src', 'config', 'translations'];

const that = {
    options: null,
    transpiler: ElmWorker.Elm.Main.init(),
};

function setupOptions(options) {
    if (that.options !== null) {
        return;
    }

    that.options = options;

    validate(schema, that.options, 'elm-symfony-bridge');

    utils.setDefaultValueIfAbsent(that.options, 'outputFolder', './elm-stuff/generated-code/elm-symfony-bridge');
    utils.setDefaultValueIfAbsent(that.options, 'projectRoot', './');
    utils.setDefaultValueIfAbsent(that.options, 'elmRoot', './assets/elm');
    utils.setDefaultValueIfAbsent(that.options, 'elmVersion', '0.19');
    utils.setDefaultValueIfAbsent(that.options, 'enableRouting', true);
    utils.setDefaultValueIfAbsent(that.options, 'lang', 'en');
    utils.setDefaultValueIfAbsent(that.options, 'enableTranslations', true);
    utils.setDefaultValueIfAbsent(that.options, 'urlPrefix', '/index.php');
    utils.setDefaultValueIfAbsent(that.options, 'envVariables', {});
    config.loadEnvVariables(that);
}

function removeGeneratedCodeFromDependencies(loader) {
    const fileDeps = loader.getDependencies();
    const contextDeps = loader.getContextDependencies();
    const missingDeps = loader.getMissingDependencies();

    loader.clearDependencies();

    fileDeps
        .filter((dep) => !dep.match(/\/(Routing|Trans\/[a-zA-Z0-9]+).elm$/))
        .forEach((dep) => loader.addDependency(dep));

    contextDeps.forEach((dep) => loader.addContextDependency(dep));
    missingDeps.forEach((dep) => loader.addMissingDependency(dep));
}

function addDirsToWatch(loader) {
    watchedDirs.forEach((dir) => loader.addContextDependency(fs.resolve(dir, that.options)));
}

module.exports = function (source) {
    removeGeneratedCodeFromDependencies(this);
    addDirsToWatch(this);

    return source;
};

module.exports.pitch = async function () {
    setupOptions(this.getOptions());

    await Promise.all([
        routing.transpile(that),
        translations.transpile(that),
    ]);
};
