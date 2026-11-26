class TasksController < ApplicationController
  def index
    @tasks = Current.user.tasks.order(:position)
  end

  def new
    @task = Current.user.tasks.build
  end

  def create
    user = Current.user
    saved = user.with_lock do
      @task = user.tasks.build(task_params)
      @task.position = user.tasks.maximum(:position).to_i + 1
      @task.save
    end

    if saved
      redirect_to tasks_path, status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def task_params
    params.expect(task: %i[name planned_duration])
  end
end
