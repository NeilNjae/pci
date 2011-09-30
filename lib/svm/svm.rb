require 'gnuplot'

class ClassifiedData
  attr_accessor :data, :classification
  
  def initialize(data = Array.new, classification = nil)
    @data = data
    @classification = classification
    self
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

def matches_to_numeric(rows)
  rows.map do |row|
    d = row.data
    ClassifiedData.new([d[0].to_f, yes_no(d[1]), yes_no(d[2]), 
             d[5].to_f, yes_no(d[6]), yes_no(d[7]), 
             match_count(d[3], d[8])],
            row.classification)
  end
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

def yes_no(v)
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

def scale_data_set(rows)
  # Could be many rows, so still make one pass through the data rather than 
  # using Array#max and #min for each data field
  lows = Array.new(rows[0].data.length, 999999999.0)
  highs = Array.new(rows[0].data.length, -999999999.0)
  rows.each do |row|
    data = row.data
    (data.length).times do |i|
      lows[i]  = data[i] if data[i] < lows[i]
      highs[i] = data[i] if data[i] > highs[i]
    end
  end
  
  scale_data = Proc.new do |row|
    row.zip(lows, highs).map {|d| (d[0] - d[1]) / (d[2] - d[1]) }
  end
  
  new_rows = rows.map do |row|
    ClassifiedData.new(scale_data.call(row.data), row.classification)
  end
  
  return new_rows, scale_data
end

# Usage:
# numeric_matches = matches_to_numeric matches
# scaled_set, scale_f = scale_data_set numeric_matches
# averages = linear_train scaled_set
# dot_product_classify(scale_f.call(numeric_matches[11].data), averages)

def radial_basis(v1, v2, gamma = 20)
  len = Math.sqrt((v1.zip v2).map {|c| (c[0] - c[1]) ** 2 }.reduce(:+))
  Math.exp(-gamma * len)
end

def nonlinear_classify(point, rows, offset, gamma = 10)
  match_sum = no_match_sum = 0.0
  match_count = no_match_count = 0
  rows.each do |row|
    if row.classification == 1
      match_sum += radial_basis(point, row.data, gamma)
      match_count += 1
    else
      no_match_sum += radial_basis(point, row.data, gamma)
      no_match_count += 1
    end
  end
  y = match_sum / match_count - no_match_sum / no_match_count + offset
  if y < 0
    0
  else
    1
  end
end

def nonlinear_offset(rows, gamma = 10)
  matches = [] ; no_matches = []
  rows.each do |r|
    if r.classification == 1
      matches << r.data
    else
      no_matches << r.data
    end
  end
  sum_matches = matches.map {|v1| matches.map {|v2| radial_basis(v1, v2, gamma)}.reduce(:+)}.reduce(:+)
  sum_no_matches = no_matches.map {|v1| no_matches.map {|v2| radial_basis(v1, v2, gamma)}.reduce(:+)}.reduce(:+)
  sum_matches / matches.length ** 2 - sum_no_matches / no_matches.length ** 2
end
