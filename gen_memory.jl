
# Load Calibre transcript and create HDB chart

if length(ARGS)!=1 
  println("### Please provide input file. ###")
  quit() 
end

last_op   = ""
op_start  = false
op_name   = ["Init"] 
last_hdb0_allocated = 0

hdbs = Vector{Int64}[]
push!(hdbs, [0])

###################################
f = ARGS[1] # File name
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
    for i in range(1, length(hdbs))
      if i==idx
        append!(hdbs[idx], parse(Int64, m[3]))  
      elseif idx==1 && i==1
        append!(hdbs[idx], last_hdb0_allocated)  
      else
        append!(hdbs[i], last(hdbs[i]))
      end
    end

    # Add operation name into array
    push!(op_name, last_op)
    continue
  end  
end

###################################
# Write out CSV data
outf_name = "$(basename(f)).csv"  
outf = open(outf_name, "w")

# Header
print(outf, "Operation") 
for i in range(1, length(hdbs))
  print(outf, ",HDB $(i-1)")
end
println(outf)

# Result in each operation
for j in range(1, length(hdbs[1]))
  print(outf, op_name[j])
  for i in range(1, length(hdbs))
    print(outf, ", $(hdbs[i][j])") 
  end
  println(outf)
end
close(outf)
###################################

# Summary 
println("### Parsing finished. ###") 
print("Array Size: $(length(op_name))")
for i in range(1, length(hdbs))
  print(", $(length(hdbs[i]))")
end
println()
println("#########################") 

# Send email
# run(pipeline(`cat .$(f)`, `mail -s "Run Result - $(f)" kala_kuo@mentor.com`))
# println("Send mail. | Log name: $f")
# run(`rm .$(f)`)         # Remove tmp file
# run(`touch .lock.$(f)`) # Create lock file