import { execSync } from 'child_process';

function runCommand(command, isDev) {
    return execSync(
        './bin/console ' + command + ' --env=' + (isDev ? 'dev' : 'prod'),
        {encoding: 'utf8', stdio: []}
    );
}

function queryConfig(configKey, isDev) {
    const config = JSON.parse(runCommand(`debug:container --parameter=${configKey} --format=json`, isDev));
    return config[configKey] || null;
}

function hasBazingaJsTranslationBundle(isDev) {
    try {
        runCommand('debug:container bazinga.jstranslation.dump_command --format=json', isDev);
        return true;
    } catch (e) {
        return false;
    }
}

function queryRouting(isDev) {
    return fixPhpJsonSerialization(runCommand('debug:router --format=json', isDev));
}

function dumpTranslations(outFolder, isDev) {
    runCommand('bazinga:js-translation:dump ' + outFolder, isDev);
}

function fixPhpJsonSerialization(content) {
    return content.startsWith('{')
        ? content
        : '{}';
}

module.exports = {
    runCommand,
    queryConfig,
    hasBazingaJsTranslationBundle,
    queryRouting,
    dumpTranslations
};
