class CompaniesController < ApplicationController
  before_action :validate_filter, only: [:search]
  def index
    @company_search = CompanySearch.new
  end

  def search
    team_size = @filter.delete(:team_size)
    query_string = URI.encode_www_form(@filter.to_h)
    if team_size.present?
      size = CGI.escape(team_size.split('-').to_s)
      size_query = "team_size=#{size}"
      query_string = query_string.blank? ? size_query : query_string+'&'+size_query
    end
    url = "https://www.ycombinator.com/companies"+'?'+query_string
    @browser = Watir::Browser.new :chrome
    @browser.goto url
    sleep 5
    data = extract_comp_count(parse_page, params[:company_search][:limit].to_i)
    respond_to do |format|
      format.csv { send_data generate_csv(data), filename: "items-#{Date.today}.csv" }
    end
    redirect_to root_url
  end

  private
  def extract_comp_count(string, input_count)
    loaded_count = string.scan(/\d+/).first.to_i
    if loaded_count < input_count
      extract_comp_count(scroll_page, input_count)
    else
      @browser.close
      return preapre_data
    end
  end

  def scroll_page
    @browser.scroll.to :bottom
    sleep 2
    parse_page
  end

  def parse_page
    html = @browser.html
    doc = Nokogiri::HTML(html)
    section =  doc.css('.ycdc-with-link-color')
    @div = section.css('._sharedDirectory_86jzd_76')
    text = @div.css('._message_86jzd_542').text
    text
  end

  def preapre_data
    result= @div.css('a._company_86jzd_338')
    message = "Preparing data ..."
    csv_data = result.each_with_object([]) do |comp, data|
      div1 = comp.child
      div2= div1.css('div')[1]
      record = div2.children.each_with_object({})  do |record, record_obj|
        record_obj['name'] = record.children.css('._coName_86jzd_453').text
        record_obj['address'] = record.children.css('._coLocation_86jzd_469').text
        record_obj['description'] = record.children.css('._coDescription_86jzd_478').text
        record_obj['batch'] = record.children.css('._pillWrapper_86jzd_33').first.child.text
        record_obj.merge!(company_detail(comp.attribute_nodes.last.value))
      end
      data.push(record)
      message += '.'
      Rails.logger.info { message }
    end
    csv_data
  end

  def generate_csv(items)
    CSV.generate(headers: true) do |csv|
      csv << %w[Sr.No Name Address Description Batch website founders]

      items.each_with_index do |item, i|
        item = item.with_indifferent_access
        csv << [i+1, item[:name], item[:address], item[:description], item[:batch], item[:website], item[:founders] ]
      end
    end
  end

  def save_csv_file(csv_data)
    file_path = Rails.root.join('tmp', "items-#{Date.today}.csv")

    File.open(file_path, 'wb') do |file|
      file.write(csv_data)
    end
  end

  def company_detail(deatil_path)
    detail_url = 'https://www.ycombinator.com'+deatil_path
    response = HTTParty.get(detail_url)
    detail_doc = Nokogiri::HTML(response.body)
    section = detail_doc.css('section').first
    website= section.css('.whitespace-nowrap').first.attribute_nodes.first.value
    founders_div = detail_doc.css('.space-y-5').empty? ? detail_doc.css('.space-y-4') : detail_doc.css('.space-y-5')
    deatil_info = founders_div.children.each_with_object({'website': website, 'founders': []}) do |founder, data|
      begin 
        linkedin = founder.css('a.bg-image-linkedin').first.attribute_nodes.first.value
      rescue
        linkedin = 'NA'
      end
      name = founder.css('h3').text
      if name.blank?
        founder_div = founder.children.first
        name = founder_div.children.last.children.first.text
      end
      data[:founders].push({name: name, linkedin: linkedin})
    end
    deatil_info
  end

  def search_params
    params[:company_search].permit(:limit, :team_size, :batch, :industry, :region, :tag, :isHiring, :nonprofit, :highlight_black, :highlight_latinx, :highlight_women )
  end

  def validate_filter
    filter = search_params.transform_values { |value| to_bool(value) }
    @filter = filter.reject { |_, value| value.blank? }
  end

  def to_bool(str)
    case str
    when '1'
      true
    when '0'
      false
    else
      str
    end
  end

end
