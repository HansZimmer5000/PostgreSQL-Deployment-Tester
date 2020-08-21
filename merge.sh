# !/bin/sh

merge_branch_source="dev"
merge_branch_targets="master feature-compose"

for branch in $merge_branch_targets; do
    git checkout $branch
    git merge $merge_branch_source
    git push
done

git checkout $merge_branch_source