import fs from 'node:fs'
import {defineConfig} from 'vite'
import {minify} from 'html-minifier-terser';

const PROD = process.env.NODE_ENV === 'production';

export default defineConfig({
  build: {
    minify: 'terser',
    terserOptions: {
      compress: {},
      format: {}
    },
    manifest: true
  },
  plugins: [
    PROD ? {
      name: 'html-optimize',
      enforce: 'post',
      transformIndexHtml: {
        enforce: 'post',
        async handler(html, ctx) {
          try {
            const cssMap = JSON.parse(fs.readFileSync('./cssmap.json').toString());
            html = html.replaceAll(
              new RegExp(/class="(.*)"/, "g"),
              (match, target) =>
                `class="${target.split(" ").map(className => cssMap[className]).join(" ")}"`
            )
            fs.unlinkSync('./cssmap.json');
            return await minify(html, {
              collapseWhitespace: true,
              removeAttributeQuotes: true,
              removeComments: true,
            })
          } catch (e) {
            console.error(e)
          }
        }
      }
    } : null
  ]
})