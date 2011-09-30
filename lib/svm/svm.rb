require 'gnuplot'

class ClassifiedData
  attr_accessor :data, :classification
  
  def initialize(data = Array.new, classification = nil)
    @data = data
    @classification = classification
  end
end

def load_data(filename, only_numbers = false)
  rows = []
  IO.foreach(filename) do |line|
    rows << ClassifiedData.new(line.chomp.split(',')[0..-2].map {|field| only_numbers ? field.to_f : field}, 
                               line.chomp.split(',')[-1].to_i)
  end
  rows
end


def plot_age_matches(rows)
  Gnuplot.open do |gp|
    Gnuplot::Plot.new( gp ) do |plot|
  
      plot.title  "Ages of matches"
      plot.ylabel "man"
      plot.xlabel "woman"

      matches = rows.select {|r| r.classification == 1}.map {|r| r.data}
      non_matches = rows.select {|r| r.classification == 0}.map {|r| r.data}
      
      plot.data = [ Gnuplot::DataSet.new( [matches] ) do |ds|
        ds.with = "points"
        ds.notitle
      end , Gnuplot::DataSet.new( [non_matches] ) do |ds|
        ds.with = "points"
        ds.notitle
      end ] 
    end
  end
end


def linear_train(rows)
  sums = {}
  averages = {}
  counts = Hash.new(0)
  
  rows.each do |row|
    row_class = row.classification
    sums[row_class] ||= [0.0] * (row.data.length)
    
    (row.data.length).times do |i|
      sums[row_class][i] += row.data[i]
    end
    counts[row_class] += 1 
  end
  
  sums.keys.each do |match_class|
    averages[match_class] = sums[match_class].map {|sum| sum / counts[match_class]}
  end
  averages
end

def dot_product(v1, v2)
  (v1.zip v2).map {|c| c.reduce(:*) }.reduce(:+)
end

def dot_product_classify(point, averages)
  b = (dot_product(averages[1], averages[1]) - dot_product(averages[0], averages[0])) / 2
  y = dot_product(point, averages[0]) - dot_product(point, averages[1]) + b
  if y > 0
    0
  else
    1
  end
end

def yesno(v)
  if v == 'yes' then 1
  elsif v == 'no' then -1
  else 0
  end
end

def match_count(interests1, interests2)
  (interests1.split(':') & interests2.split(':')).length
end

def miles_distance(a1, a2)
  0
end


