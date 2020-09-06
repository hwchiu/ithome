const gulp = require('gulp');
const gulpLoadPlugins = require('gulp-load-plugins');
const sitemap = require('gulp-sitemap');

const $ = gulpLoadPlugins();

gulp.task('publish', () => {
  console.log('Publish Gitbook (_book) to Github Pages');
  gulp.src('./_book/*/**/*.html', {
            read: false
        })
        .pipe(sitemap({
            siteUrl: 'http://ithome.hwchiu.com'
        }))
        .pipe(gulp.dest('./_book/'));

  return gulp.src('./_book/**/*')
    .pipe($.ghPages({
      origin: 'origin',
      branch: 'gh-pages'
    }));
});
