using DataFrames
using PyPlot 

# Load HDB LVHEAP data (assuming generated from gen_memory.jl
# Plot chart using PyPlot
# kkuo @ 2017.9.14

if length(ARGS)<1 
  println("### Please provide input file. ###")
  quit() 
end

for f in ARGS
  println("### Processing $(f)... ###")

  outf_name = if contains(basename(f), ".csv") replace(basename(f), ".csv", ".png") else "$(basename(f)).png" end

  # Read into Dataframe
  data = readtable(f)

  # Parameters
  x         = 1:length(data[1])
  width     = 10.5 
  height    = length(x)/6
  hdb_count = length(names(data)) - 2 

  # Init figure and axis
  fig, ax = subplots()
  fig[:set_size_inches](width, height, forward=true)

  # Add lines for each HDB
  for i in 0:hdb_count-1
    ax[:plot](reverse(Array(data[3+i])), x, linewidth=2, alpha=0.6)
  end

  # Adjust xticks - add some minor ticks
  mx = matplotlib[:ticker][:MultipleLocator](10000) # Define interval of minor ticks
  ax[:xaxis][:set_minor_locator](mx) # Set interval of minor ticks
  ax[:xaxis][:set_tick_params](top=true, labeltop=true)

  # https://stackoverflow.com/questions/10679612/is-it-possible-to-draw-a-plot-vertically-with-python-matplotlib
  # Disable due to overlap with Title
  # ax[:xaxis][:tick_top]()

  # Adjust yticks - Show all yticks
  # ax[:set_yticklabels](ytick_labels)
  ytick_labels = reverse(data[1])
  yticks(x, ytick_labels)

  # Add Legend
  ax[:legend](names(data[end-hdb_count+1:end]))

  xlabel("LVHEAP", fontsize=20)
  ylabel("Operations", fontsize=32)
  # title("HDB Trend Chart", fontsize=36)
  grid("on")

  fig[:tight_layout]()
  fig[:savefig](outf_name, bbox_inches="tight", dpi=100)
end
