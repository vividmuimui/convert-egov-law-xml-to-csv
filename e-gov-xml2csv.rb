require 'rexml/document'
require 'csv'

# 使い方
# ruby e-gov-xml2csv.rb in.xml out.csv
# 例: ruby e-gov-xml2csv.rb 347AC0000000057_20220617_504AC0000000068.xml 347AC0000000057_20220617_504AC0000000068_労働安全衛生法.csv
# xmlはe-govからダウンロードしたものを使う。 https://elaws.e-gov.go.jp/
#
# 法令の文章の構造についてはこちらを参考: https://www.mirai-inc.jp/support/roppo/basic-knowledge.pdf
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
  validate_artice_num(result)
  write_csv(out_file, result)
end


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
  header_hash = {
    part_num: "編",
    part_title: "編タイトル",
    chapter_num: "章",
    chapter_title: "章タイトル",
    section_num: "節",
    section_title: "節タイトル",
    subsection_num: "款",
    subsection_title: "款タイトル",
    division_num: "目",
    division_title: "目タイトル",
    article_num: "条",
    article_title: "条タイトル",
    paragraph_num: "項",
    text: "本文"
  }

  CSV.open(out_file, "w", force_quotes: true) do |csv|
    csv << header_hash.values
    result.each do |hash|
      csv << header_hash.keys.map { |key| hash[key] }
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

    if chapter.elements['Section']
      result << parse_section(chapter).map { |hash| hash.merge(chapter_num: chapter_num, chapter_title: chapter_title) }
    else
      result << parse_article(chapter).map { |hash| hash.merge(chapter_num: chapter_num, chapter_title: chapter_title) }
    end
  end
  result.flatten
end

def parse_section(element)
  result = []
  element.elements.each('Section') do |section|
    section_num = section.attributes['Num']
    section_title = section.elements['SectionTitle'].text

    if section.elements['Subsection']
      result << parse_subsection(section).map { |hash| hash.merge(section_num: section_num, section_title: section_title) }
    else
      result << parse_article(section).map { |hash| hash.merge(section_num: section_num, section_title: section_title) }
    end
  end
  result.flatten
end

def parse_subsection(element)
  result = []
  element.elements.each('Subsection') do |subsection|
    subsection_num = subsection.attributes['Num']
    subsection_title = subsection.elements['SubsectionTitle'].text

    if subsection.elements['Division']
      result << parse_division(subsection).map { |hash| hash.merge(subsection_num: subsection_num, subsection_title: subsection_title) }
    else
      result << parse_article(subsection).map { |hash| hash.merge(subsection_num: subsection_num, subsection_title: subsection_title) }
    end
  end
  result.flatten
end

def parse_division(element)
  result = []
  element.elements.each('Division') do |division|
    division_num = division.attributes['Num']
    division_title = division.elements['DivisionTitle'].text

    result << parse_article(division).map { |hash| hash.merge(division_num: division_num, division_title: division_title) }
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

def sequential_article_num?(previous_nums, current_nums, previous, current)
  if previous_nums.size == current_nums.size
    if previous_nums.last == current_nums.last
      # previous: 2章1項, current: 2章2項 のようなケース
      unless previous[:paragraph_num].to_i + 1 == current[:paragraph_num].to_i
        # raise "項番号が連続していません: previous: #{previous}, current: #{current}, previous: #{previous}, current: #{current}"
        return false
      end
    elsif previous_nums.last + 1 != current_nums.last
      # raise "条番号が連続していません: previous: #{previous_nums}, current: #{current_nums}, previous: #{previous}, current: #{current}"
      return false
    end
  end

  # previous: [66, 8], current: [66, 8, 2] のようなケース
  if previous_nums.size + 1 == current_nums.size
    unless current_nums.last == 2
      # raise "条番号が連続していません: previous: #{previous_nums}, current: #{current_nums}, previous: #{previous}, current: #{current}"
      return false
    end
  end

  # previous: [66, 8, 4], current: [66, 9] のようなケース
  if previous_nums.size == current_nums.size + 1
    unless previous_nums[-2] + 1 == current_nums.last
      # raise "条番号が連続していません: previous: #{previous_nums}, current: #{current_nums}, previous: #{previous}, current: #{current}"
      return false
    end
  end
  return true
end

def validate_artice_num(result)
  previous = nil
  previous_nums = nil

  result.each do |current|
    current_num_text = current[:article_num]
    current_nums = current_num_text.split('_').map(&:to_i)

    unless previous_nums
      previous_nums = current_nums
      previous = current
      next
    end

    # previous: 95_3_2, current: 95_4:95_5 のようなケース。複数条文が削除されているときこの表記になる
    if current_num_text.include?(':')
      current_first_nums = current_num_text.split(':').first.split('_').map(&:to_i)
      current_last_nums = current_num_text.split(':').last.split('_').map(&:to_i)

      unless sequential_article_num?(previous_nums, current_first_nums, previous, current)
        raise "条番号が連続していません: previous: #{previous_nums}, current: #{current_nums}, previous: #{previous}, current: #{current}"
      end
      previous_nums = current_last_nums
      previous = current
      next
    else
      unless sequential_article_num?(previous_nums, current_nums, previous, current)
        raise "条番号が連続していません: previous: #{previous_nums}, current: #{current_nums}, previous: #{previous}, current: #{current}"
      end
    end

    previous_nums = current_nums
    previous = current
  end
end

main()
