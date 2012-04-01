# encoding: utf-8
require 'splitter'
require 'text'

class Document
  include Mongoid::Document
  include Mongoid::Timestamps

  field :title,         type: String
  field :heading,       type: String
  field :category,      type: String
  field :content,       type: String
  field :published_at,  type: Date
  field :description,   type: String
  field :original_file, type: String

  has_many :milestones
  has_and_belongs_to_many :people
  embeds_many :paragraphs

  after_create :split, :analyze

  attr_accessor :sample_mode


  # Split original document data and extract metadata and content as clean,
  # plain text for further analysis.
  #
  def split
    if self.original_path
      # Replace title with original title from document
      self.title = Splitter.extract_title(self.original_path)
      text = Splitter.extract_plain_text(self.original_path)
      text.split(".\n").each do |paragraph|
        self.paragraps << Paragraph.new(:content => paragraph) if paragraph != ""
      end
      save
    end
  end

  # Perform a morphological analysis and extract named entities like persons,
  # organizations, places, dates and addresses.
  #
  # From the detected entities, create Person instances and try to resolve
  # correference, if possible.
  #
  def analyze
    # TODO
  end


  def original_path
    File.join(USER_DIR, self.original_file) if self.original_file
  end

  def _dump(level)
    id.to_s
  end

  def self._load(arg)
    self.find(arg)
  end

  # deprecated
  def path
    File.join(File.expand_path(File.dirname(__FILE__)), "../../", "data", "#{id}.txt")
  end

  # deprecated
  def length
    fd { |fd| fd.read.size }
  end

  # deprecated
  def fd(&block)
    require 'stringio'
    yield StringIO.new(self.content)
  end

  # deprecated
  def read(*p)
    if p.empty?
      @___text ||= fd { |fd| fd.read }
    else
      fd { |fd| fd.read(*p) }
    end
  end

  def fragment(start_pos, end_pos)
    text = read()
    fragment = text[start_pos ... end_pos]
    Text::StringWithContext.new_with_context(fragment, text, start_pos, end_pos, self)
  end

  # deprecated
  def extract
    @process_text ||= Text.new(self)
  end

  # deprecated
  def method_missing(p, args=[])
    fd.send(p, *args)
  end

  def add_person(person, mentions=1)
    r = false
    if person_dataset.filter(:person_id => person.id).empty?
      r = super(person)
    end
    doc_id = self.id
    person_id = person.id
    DocumentsPerson.filter(:document_id => doc_id, :person_id => person_id).set(:mentions => :mentions + mentions)
    r
  end
end
