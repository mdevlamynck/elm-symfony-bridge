import ElmWorker from '../src/Main.elm';
import picomatch from 'picomatch';
import config from '../src/config.js';
import fs from '../src/filesystem.js';
import routing from '../src/routing.js';
import translations from '../src/translations.js';
import utils from '../src/utils.js';

const isElm = (id) => {
    const parsedId = new URL(id, 'file://');
    const pathname = parsedId.pathname;
    return pathname.endsWith('.elm') && !parsedId.searchParams.has('raw');
}

export default function elmSymfonyBridgePlugin (userConfig) {
    let needBuilding = true;
    let needRebuilding = true;
    let toRebuild = new Set();
    let global = {
        transpiler: ElmWorker.Elm.Main.init(),
        options: {},
    };
    let hmrPatterns = [];

    return {
        name: 'vite-plugin-elm-symfony-bridge',

        buildStart (options) {
            global.options = utils.overrideDefaultsIfProvided(userConfig, {
                watch: this.meta.watchMode,
                dev: process.env.NODE_ENV !== 'production',
                projectRoot: './',
                elmRoot: './assets/elm',
                outputFolder: './elm-stuff/generated-code/elm-symfony-bridge',
                elmVersion: '0.19',
                enableRouting: true,
                urlPrefix: '',
                enableTranslations: true,
                lang: 'fr',
                watchFolders: ['src', 'app', 'config', 'translations'],
                watchExtensions: ['php', 'yaml', 'yml', 'xml'],
                envVariables: {},
            });

            config.loadEnvVariables(global);

            hmrPatterns = utils.combinations(
                global.options.watchFolders,
                global.options.watchExtensions,
                (folder, extension) => picomatch(fs.resolve(folder, global.options) + '/**/*.' + extension)
            );
        },

        load: {
            order: 'pre',
            handler(id) {
                if (!isElm(id)) {
                    return null;
                }

                needRebuilding = true;
                toRebuild.add(id);

                if (!needBuilding) {
                    return null;
                }

                routing.transpile(global);
                translations.transpile(global);

                needBuilding = false;

                return null;
            }
        },

        handleHotUpdate (ctx) {
            if (needRebuilding && utils.arrayAny(hmrPatterns, (isMatch) => isMatch(ctx.file))) {
                needRebuilding = false;

                routing.transpile(global);
                translations.transpile(global);
            }

            return ctx.modules;
        },
    }
}
