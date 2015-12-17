require 'nokogiri'

class Html2Text
  attr_reader :doc

  def initialize(doc)
    @doc = doc
  end

  def self.convert(html)
    html = fix_newlines(replace_entities(html))
    doc = Nokogiri::HTML(html)

    Html2Text.new(doc).convert
  end

  def self.fix_newlines(text)
    text.gsub("\r\n", "\n").gsub("\r", "\n")
  end

  def self.replace_entities(text)
    text.gsub("&nbsp;", " ")
  end

  def convert
    output = iterate_over(doc)
    output = remove_leading_and_trailing_whitespace(output)
    output.strip
  end

  def remove_leading_and_trailing_whitespace(text)
    text.gsub(/[ \t]*\n[ \t]*/im, "\n")
  end

  def trimmed_whitespace(text)
    # Replace whitespace characters with a space (equivalent to \s)
    text.gsub(/[\t\n\f\r ]+/im, " ")
  end

  def next_node_name(node)
    next_node = node.next_sibling
    while next_node != nil
      break if next_node.element?
      next_node = next_node.next_sibling
    end

    if next_node && next_node.element?
      next_node.name.downcase
    end
  end

  def iterate_over(node)
    return trimmed_whitespace(node.text) if node.text?

    if ["style", "head", "title", "meta", "script"].include?(node.name.downcase)
      return ""
    end

    output = []

    output << prefix_whitespace(node)
    output += node.children.map do |child|
      iterate_over(child)
    end
    output << suffix_whitespace(node)

    output = output.compact.join("") || ""

    if node.name.downcase == "a"
      output = wrap_link(node, output)
    end

    output
  end

  def prefix_whitespace(node)
    case node.name.downcase
      when "hr"
        "------\n"

      when "h1", "h2", "h3", "h4", "h5", "h6", "ol", "ul"
        "\n"

      when "tr", "p", "div"
        "\n"

      when "td", "th"
        "\t"

      when "li"
        "- "
    end
  end

  def suffix_whitespace(node)
    case node.name.downcase
      when "h1", "h2", "h3", "h4", "h5", "h6"
        # add another line
        "\n"

      when "p", "br"
        "\n" if next_node_name(node) != "div"

      when "li"
        "\n"

      when "div"
        # add one line only if the next child isn't a div
        "\n" if next_node_name(node) != "div" && next_node_name(node) != nil
    end
  end

  # links are returned in [text](link) format
  def wrap_link(node, output)
    href = node.attribute("href")
    name = node.attribute("name")

    if href.nil?
      if !name.nil?
        output = "[#{output}]"
      end
    else
      href = href.to_s

      if href != output && href != "mailto:#{output}" &&
          href != "http://#{output}" && href != "https://#{output}"
        output = "[#{output}](#{href})"
      end
    end

    case next_node_name(node)
      when "h1", "h2", "h3", "h4", "h5", "h6"
        output += "\n"
    end

    output
  end
end