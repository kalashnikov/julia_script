# Load list and monitor Calibre transcript 

cd() # Go to home dir
for dir in eachline(".monitor_list")
    cd(chomp(dir))
    println("### Scanning folder: $(dir) ###")
    v = String[]
    for f in readdir()
        if ismatch(r"^run.*log", f)
            # Check File already process and finished or not
            if isfile(".lock.$(f)")
                continue
            end
            is_finished = false
            for l in eachline(`tail $(f)`)
                if ismatch(r"TOTAL CPU TIME = ", chomp(l))
                    is_finished = true
                    break
                end
            end
            if is_finished
                push!(v, f)
            end
        end
    end
    for f in v
        outf_name = ".$(f)"  # Create tmp file
        outf = open(outf_name, "w")
        for l in eachline(f)
            op_complete = ismatch(r"^Operation COMPLETED on ", l)
            if ismatch(r"--- ", l) ||
                ismatch(r"^// ", l) ||
                ismatch(r"HGC=\d+ FGC", l) ||
                ismatch(r"WARNING: ", l) ||
                ismatch(r"^CPU TIME = ", l) ||
                op_complete
                println(outf, l)
                if op_complete
                    println(outf)
                end
            end
        end
        close(outf)
        # Send email
        run(pipeline(`cat .$(f)`, `mail -s "Run Result - $(f)" kala_kuo@mentor.com`))
        println("Send mail. | Log name: $f")
        run(`rm .$(f)`)         # Remove tmp file
        run(`touch .lock.$(f)`) # Create lock file
    end
end
