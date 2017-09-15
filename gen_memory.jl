using DataFrames
using PyPlot 

if length(ARGS)<1 
  println("### Please provide input file. ###")
  quit() 
end

# Output data list
outfiles = String[]

###################################
# Load Calibre transcript and create HDB LVHEAP data 
# kkuo @ 2017.9.13
#
# Generate memory data in CSV format 
for f in ARGS

  last_op   = ""
  op_start  = false
  op_name   = String["Init"] 
  last_hdb0_allocated = 0

  op_at = String["Init"] 

  hdbs = Vector{Int64}[]
  push!(hdbs, [0])

  println("### Processing $(f)...")
  for l in eachline(f)

    ### Pre-operation Init. ### 
    if !op_start
      op_start = ismatch(r"EXECUTIVE MODULE", l)

      # //  Initializing MT on pseudo HDB 4
      if ismatch(r"on pseudo HDB", l)
        push!(hdbs, [0])
      end

      # PSEUDO HDB 2 CONSTRUCTED.  CPU TIME = 18  REAL TIME = 29  LVHEAP = 4443/5399/5404
      if ismatch(r"PSEUDO HDB (\d+) CONSTRUCTED. .*LVHEAP = (\S+)", l)
        m = match(r"PSEUDO HDB (\d+) CONSTRUCTED. .*LVHEAP = (\d+)/(\d+)/(\d+)", l)
        hdbs[parse(Int64, m[1])+1][1] = parse(Int64, m[3])

        # PSEUDO HDB SYSTEM CONSTRUCTION COMPLETE: 0 CPU TIME = 52  REAL TIME = 30  LVHEAP = 42272/106951/106956  SHARED = 35393/35424
      elseif ismatch(r"PSEUDO HDB SYSTEM CONSTRUCTION COMPLETE: (\d+) .*LVHEAP = (\S+)", l)
        m = match(r"PSEUDO HDB SYSTEM CONSTRUCTION COMPLETE: (\d+) .*LVHEAP = (\d+)/(\d+)/(\d+)", l)
        hdbs[parse(Int64, m[1])+1][1] = parse(Int64, m[3])
      end

      # Finishing pre-operation init.
      continue
    end

    ### Now the operation is started. ###

    # Quick check to skip non target line
    if length(strip(l))==0 || 
      length(strip(l, '-'))==0 || 
      contains(l, "Operation EXECUTING on") ||
      contains(l, "WARNING") ||
      contains(l, "DELETED -- LVHEAP") 
      continue
    end

    # DV7_C (HIER TYP=1 CFG=1 HGC=2 FGC=2 HEC=8 FEC=8 IGC=0 VHC=F VPC=X) 
    op_name_get = ismatch(r"^\S+\s.*HIER.*HGC=", l)
    if op_name_get 
      m = match(r"^(\S+)\s.*HIER",l)
      last_op = m[1]
      continue 
    end

    lvheap_stat = ismatch(r"^CPU TIME = ", l)
    if lvheap_stat
      # CPU TIME = 0  REAL TIME = 0  LVHEAP = 42298/106954/106956  SHARED = 35393/35424  OPS COMPLETE = 1 OF 4963  ELAPSED TIME = 21154
      m = match(r"CPU TIME = (\S+)  REAL TIME = (\S+)  LVHEAP = (\S+)/(\S+)/(\S+)",l)
      last_hdb0_allocated = parse(Int64, m[4])
      continue
    end

    op_complete = ismatch(r"^Operation COMPLETED on HDB ", l)
    if op_complete
      # Operation COMPLETED on HDB 0  LVHEAP = 42298/106954/106956
      m = match(r"^Operation COMPLETED on HDB (\S+)  LVHEAP = (\S+)/(\S+)/(\S+)", l)
      idx = parse(Int64, m[1])+1
      val = parse(Int64, m[3])

      # Check if LVHEAP size is increased
      if last(hdbs[idx])==val 
        continue
      end

      for i in range(1, length(hdbs))
        if i==idx
          append!(hdbs[idx], val)  
        elseif idx==1 && i==1
          append!(hdbs[idx], last_hdb0_allocated)  
        else
          append!(hdbs[i], last(hdbs[i]))
        end
      end

      # Add operation name into array
      push!(op_name, last_op)
      push!(op_at, "$(idx-1)")
      continue
    end  
  end

  ###################################
  # Write out CSV data
  outf_name = if contains(basename(f), ".log") replace(basename(f), ".log", ".csv") else "$(basename(f)).csv" end
  
  outf = open(outf_name, "w")

  # Header
  print(outf, "Operation, At") 
  for i in range(1, length(hdbs))
    print(outf, ", HDB $(i-1)")
  end
  println(outf)

  # Result in each operation
  for j in range(1, length(hdbs[1]))
    print(outf, "$(op_name[j]), $(op_at[j])")
    for i in range(1, length(hdbs))
      print(outf, ", $(hdbs[i][j])") 
    end
    println(outf)
  end
  close(outf)

  push!(outfiles, outf_name)
  ###################################
end

###################################
# Load HDB LVHEAP data (assuming generated from gen_memory.jl
# Plot chart using PyPlot
# kkuo @ 2017.9.13

# Generate memory trend chart
for f in outfiles
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

  println("### Generate $(outf_name). ###")
end
###################################
