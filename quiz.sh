#!/bin/bash

file="questions.txt"

# A better improved path for highscores file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
highscores_file="$SCRIPT_DIR/highscores.txt"

Questions=()

#Handling command line arguments
print_top_5() {
    if [[ ! -f "$highscores_file" || ! -s "$highscores_file" ]]; then
        echo "No high scores found yet."
        return
    fi
    echo "-----------------------------"
    echo "=======Top 5 Scores:======="
    echo "-----------------------------"

    #'Sort' safety and ensures awk handles the format correctly 
    sort -t'|' -k5 -nr "$highscores_file" 2>/dev/null | head -5 | \
    awk -F'|' '{ printf "%-2d. %-15s %3d%% (%d/%d correct) [%s]\n", NR, $1, $5, $2, $4, $6 }'
    echo "-----------------------------------------------------------"
}

if [[ "$1" == "highscores" ]]; then
    print_top_5
    exit 0
fi

# Check file exists and is not empty
if [[ ! -s "$file" ]]; then
    echo "Error: Question file missing or empty"
    exit 1
fi

# Read questions The "||" helps to insist on reading to the last line in the question.txt
while IFS='|' read -r question opt_A opt_B opt_C opt_D correct _ || [[ -n "$question" ]]; do
    [[ -z "$question" ]] && continue
    if [[ -n "$question" && -n "$opt_A" && -n "$opt_B" && -n "$opt_C" && -n "$opt_D" && -n "$correct" ]]; then
        Questions+=("$question|$opt_A|$opt_B|$opt_C|$opt_D|$correct")
    fi
# Redirects a file into the loop
done < "$file"

# Check questions loaded
if [[ ${#Questions[@]} -eq 0 ]]; then
    echo "Error: No valid questions found in '$file'!"
    exit 1
fi

echo "Loaded ${#Questions[@]} questions successfully."

# Shuffle questions
mapfile -t Questions < <(printf "%s\n" "${Questions[@]}" | shuf)

# Function to display question instead of using echo question 1 of 15 {=defines function boundary
display_question() {
    question_num=$1
    total=$2
    question_data=$3

    IFS='|' read -r question opt_A opt_B opt_C opt_D _ <<< "$question_data"
    echo "======================================================"
    echo "Question $question_num of $total"
    echo "$question"
    echo ""
    echo "$opt_A"
    echo "$opt_B"
    echo "$opt_C"
    echo "$opt_D"
    echo ""
}

# Function to validate answer and check first argument ($1) in uppercase
validate_answer() {
    [[ "${1^^}" =~ ^[ABCD]$ ]]
}

if [[ "$1" == "practice" ]]; then 
    mode="practice"; username="practice mode"; echo "Practice Mode selected"

else
    mode="normal";
    echo "Normal Mode selected"
fi

# Username input
echo "=============================="
echo "      Start Quiz Game!        "
echo "=============================="

if [[ -z "$username" ]]; then 
    read -rp "Please enter your username: " username
    while [[ -z "$username" ]]; do
        read -rp "Username cannot be empty. Enter again: " username
    done
fi

echo "Welcome, $username!"

sleep 2

# Initialize stats
total_questions=${#Questions[@]}
score=0
incorrect=0
current_streak=0
longest_streak=0
qnum=0

# Quiz loop
for i in "${!Questions[@]}"; do
    ((qnum++))
    clear
    # Uses a function name called display...starting from 1, 2, 3... right up to a full question string.
    display_question "$qnum" "$total_questions" "${Questions[$i]}"

    # Extracts the correct answer
    IFS='|' read -r _ _ _ _ _ correct_answer <<< "${Questions[$i]}"
    correct_answer=$(echo "$correct_answer" | tr -d '\r' | xargs)
    # Get user answer
    while true; do    
        printf "[%s] Your answer (A/B/C/D): " "$(date "+%H:%M:%S")" 

        read -r user_answer

        user_answer="${user_answer^^}"

        if validate_answer "$user_answer"; then
            if [[ "$user_answer" == "$correct_answer" ]]; then
                echo -e "\e[32mCorrect!\e[0m"
                ((score++))
                ((current_streak++))
                [[ $current_streak -gt $longest_streak ]] && longest_streak=$current_streak
            else
                 echo -e "\e[31mWrong! The correct answer was $correct_answer\e[0m"
                ((incorrect++))
                current_streak=0
            fi           
            break
        else
            echo -n "Invalid input! Please enter A, B, C, or D: "
        fi
    done 
    user_answer=$(echo "$user_answer" | xargs)
   
    if [[ $qnum -lt "$total_questions" ]]; then
        echo -e "\nProgress: $qnum/$total_questions"
        read -rp "Press Enter to continue..."
    fi
done

# Calculate percentage and starting time
pct=0
pct=$(( total_questions > 0 ? (score * 100) / total_questions : 0 ))
final_dt=$(date "+%Y-%m-%d %H:%M")
# Results
clear
echo "==== Quiz Over ===="
echo "Questions Processed: $qnum"

if [[ "$mode" == "normal" ]]; then
    echo "$username|$score|$incorrect|$total_questions|$pct|$final_dt" >> "$highscores_file"

    echo "Incorrect Answers: $incorrect"
    echo "Longest Streak: $longest_streak"
    echo "Final Score: $score / $total_questions"
    
    print_top_5
else
    echo "Practice mode: No score recorded"
fi
