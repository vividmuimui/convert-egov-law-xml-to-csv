require 'rexml/document'
require 'csv'

def extract_text_without_ruby(element)
  element.delete_element('Ruby/Rt')
  return REXML::XPath.match(element, './/text()').map(&:value).join
end

def extract_texts_without_ruby(element, key)
  element.elements.collect(key) { |e| extract_text_without_ruby(e) }
end

def parse_args
  in_file = ARGV.shift
  if in_file.nil? || in_file.empty?
    puts '読み込むファイル名を指定してください'
    exit
  end

  out_file = ARGV.shift
  if out_file.nil? || out_file.empty?
    puts '出力するファイル名を指定してください'
    exit
  end

  [in_file, out_file]
end

def write_csv(out_file, result)
  CSV.open(out_file, "w", force_quotes: true) do |csv|
    csv << ["編", "編タイトル", "章", "章タイトル", "条", "条タイトル", "項", "本文"]
    result.each do |hash|
      csv << [hash[:part_num], hash[:part_title], hash[:chapter_num], hash[:chapter_title], hash[:article_num], hash[:article_title], hash[:paragraph_num], hash[:text]]
    end
  end
  puts "#{result.size}データを出力しました: #{out_file}"
end

def run_for_type_Act(doc)
  appl_data = doc.elements['DataRoot/ApplData']
  puts({
    "LawType": appl_data.elements['LawFullText/Law'].attributes['LawType'],
    "LawId": appl_data.elements['LawId'].text,
    "LawName": appl_data.elements['LawFullText/Law/LawNum'].text,
  })

  parse_main_provision(appl_data.elements['LawFullText/Law/LawBody/MainProvision'])
end

def run_for_type_MinisterialOrdinance(doc)
  law = doc.elements['Law']
  puts({
    "LawType": law.attributes['LawType'],
    "LawNum": law.elements['LawNum'].text,
    "LawName": law.elements['LawBody/LawTitle'].text,
  })
  parse_main_provision(law.elements['LawBody/MainProvision'])
end

def run_for_type_CabinetOrder(doc)
  law = doc.elements['Law']
  puts({
    "LawType": law.attributes['LawType'],
    "LawNum": law.elements['LawNum'].text,
    "LawName": law.elements['LawBody/LawTitle'].text,
  })
  parse_main_provision(law.elements['LawBody/MainProvision'])
end

def parse_main_provision(element)
  case
  when element.elements['Part']
    parse_part(element)
  when element.elements['Chapter']
    parse_chapter(element)
  when element.elements['Article']
    parse_article(element)
  else
    puts '対応してない階層のxmlです'
  end
end

def parse_part(element)
  result = []
  element.elements.each('Part') do |part|
    part_num = part.attributes['Num']
    part_title = part.elements['PartTitle'].text
    result << parse_chapter(part).map { |hash| hash.merge(part_num: part_num, part_title: part_title) }
  end
  result.flatten
end

def parse_chapter(element)
  result = []
  element.elements.each('Chapter') do |chapter|
    chapter_num = chapter.attributes['Num']
    chapter_title = chapter.elements['ChapterTitle'].text

    result << parse_article(chapter).map { |hash| hash.merge(chapter_num: chapter_num, chapter_title: chapter_title) }
  end
  result.flatten
end

def parse_article(element)
  result = []
  element.elements.each('Article') do |article|
    article_num = article.attributes['Num']
    article_title = article.elements['ArticleTitle'].text
    article_caption = article.elements['ArticleCaption']&.text || nil

    article.elements.each('Paragraph') do |paragraph|
      paragraph_num = paragraph.attributes['Num']
      # paragraph_num = paragraph.elements['ParagraphNum'].text || '' # 1項目は番号が振られてないことがある
      paragraph_texts = extract_texts_without_ruby(paragraph, 'ParagraphSentence/Sentence')
      has_table = paragraph.elements['TableStruct']

      item_texts = paragraph.elements.collect('Item') do |item|
        item_title = item.elements['ItemTitle'].text
        item_sentence_texts = [
          extract_texts_without_ruby(item, 'ItemSentence/Sentence'),
          extract_texts_without_ruby(item, 'ItemSentence/Column/Sentence')
        ].flatten
        "#{item_title} #{item_sentence_texts.join(' ')}"
      end

      paragraph_text = paragraph_texts.join
      item_text = item_texts.join("\n")
      table_text = has_table ? '(本来はここに表が入るがCSV化のときに未対応)' : ''
      text = [paragraph_text, item_text, table_text].reject(&:empty?).join("\n")

      result << {
        article_num: article_num,
        article_title: [article_title, article_caption].compact.join(' '),
        paragraph_num: paragraph_num,
        text: text,
      }
    end
  end
  result
end

def main
  in_file, out_file = parse_args
  doc = REXML::Document.new(File.open(in_file))
  law = doc.elements['Law']
  puts({
    "LawType": law.attributes['LawType'],
    "LawNum": law.elements['LawNum'].text,
    "LawName": law.elements['LawBody/LawTitle'].text,
  })
  result = parse_main_provision(law.elements['LawBody/MainProvision'])
  write_csv(out_file, result)
end

# 使い方
# ruby e-gov-xml2csv.rb in.xml out.csv
# 例: ruby e-gov-xml2csv.rb 347AC0000000057_20220617_504AC0000000068.xml 347AC0000000057_20220617_504AC0000000068_労働安全衛生法.csv
# xmlはe-govからダウンロードしたものを使う。 https://elaws.e-gov.go.jp/
main()
