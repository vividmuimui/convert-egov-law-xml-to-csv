# convert-egov-law-xml-to-csv

e-Govの法令検索/APIのxmlをcsvに変換するスクリプト

## Usage

xmlはe-govからダウンロードしたものを使う。 https://elaws.e-gov.go.jp/

```sh
ruby e-gov-xml2csv.rb in.xml out.csv
# 例: ruby e-gov-xml2csv.rb 347AC0000000057_20220617_504AC0000000068.xml 347AC0000000057_20220617_504AC0000000068_労働安全衛生法.csv
```

## TODO(未対応)


- 文章中の表の表示。「(本来はここに表が入るがCSV化のときに未対応)」という文章が差し込まれる
- 「附則」や「別表」の表示

## Development

### 補足

法令の文章の構造についてはこちらを参考: https://www.mirai-inc.jp/support/roppo/basic-knowledge.pdf
