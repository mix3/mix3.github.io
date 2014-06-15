# mix3.github.io

mix3のブログ

## コンセプト

* レスポンシブデザイン頑張る
* SEOに弱くならない程度に静的ページ
* [Octopress](http://octopress.org/)とかそういう感じっぽく

## 修正に際して

* 個別記事のURL変更 /:year/:month/:name -> /blog/:year/:month/:name
 * リポジトリがどんどん汚れてくのでやっぱりディレクトリ掘りたくなった
 * はてブがあれだけど仕方ないね
* page.js使って動的遷移も出来るようにしたかったけど諦めた
 * embedを解決する方法思いつかない

## 使ってる技術

* [Perl](http://www.perl.org/)
* [Simple Grid](http://thisisdallas.github.io/Simple-Grid/)
* [jQuery](http://jquery.com/)

[Page.js](http://visionmedia.github.io/page.js/)とか[Routie](http://projects.jga.me/routie/)とかで簡単な動的表現をやってみたかったけど、&lt;script&gt;をappendしてもうまくいかないことが多いのでやめた

## ページ一覧

URL                      | 内容                     | 詳細                                | ページング | 表示数
------------------------ | ------------------------ | ----------------------------------- | ---------- | -----
/                        | /page/1 と同じ           | [{タイトル, 本文, 日時, タグ}, ...] | 有         | N..M
/page/:num               | 記事一覧                 | [{タイトル, 本文, 日時, タグ}, ...] | 有         | N..M
/archive                 | 記事タイトル一覧         | [{タイトル, 日時, タグ}, ...]       | 無         | ALL
/tags/:name              | 記事タイトル一覧(タグ別) | [{タイトル, 日時, タグ}, ...]       | 無         | ALL
/blog/:year/:month/:name | 記事                     | {タイトル, 本文, 日時, タグ}        | 有         | ONE
