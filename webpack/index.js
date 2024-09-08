import { ElmWorker, config, data, fs, generate } from 'elm-symfony-bridge-lib';
import schema from './schema.json';
import { validate } from 'schema-utils';

const watchedDirs = ['src', 'config', 'translations'];

const global = {
    options: null,
    transpiler: ElmWorker.Elm.Main.init(),
};

function setupOptions(options) {
    if (global.options !== null) {
        return;
    }

    global.options = options;

    validate(schema, global.options, 'elm-symfony-bridge');

    data.setDefaultValueIfAbsent(global.options, 'outputFolder', './elm-stuff/generated-code/elm-symfony-bridge');
    data.setDefaultValueIfAbsent(global.options, 'projectRoot', './');
    data.setDefaultValueIfAbsent(global.options, 'elmRoot', './assets/elm');
    data.setDefaultValueIfAbsent(global.options, 'elmVersion', '0.19');
    data.setDefaultValueIfAbsent(global.options, 'enableRouting', true);
    data.setDefaultValueIfAbsent(global.options, 'lang', 'en');
    data.setDefaultValueIfAbsent(global.options, 'enableTranslations', true);
    data.setDefaultValueIfAbsent(global.options, 'urlPrefix', '/index.php');
    data.setDefaultValueIfAbsent(global.options, 'envVariables', {});
    config.loadEnvVariables(global);
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
    watchedDirs.forEach((dir) => loader.addContextDependency(fs.resolve(dir, global.options)));
}

module.exports = function (source) {
    try {
        removeGeneratedCodeFromDependencies(this);
        addDirsToWatch(this);

        return source;
    } catch (e) {
        this.emitError(e);
    }
};

module.exports.pitch = async function () {
    try {
        setupOptions(this.getOptions());

        await generate(global);
    } catch (e) {
        this.emitError(e);
    }
};
